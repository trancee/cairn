//! Automatic admission limits and the P0 tie-break (spec §5.6, ADR 0021).

use alloc::collections::VecDeque;
use alloc::vec::Vec;
use core::cmp::Ordering;

const HOUR_MS: u64 = 3_600_000;
/// The back-off after a first transport failure; each further one doubles it.
const BASE_BACK_OFF_MS: u64 = 120_000;
pub(crate) const MAX_ADMITTED_PER_HOUR: usize = 10;
pub(crate) const MAX_ATTEMPTS_PER_HOUR: usize = 30;
pub(crate) const MAX_NEIGHBOURS: usize = 256;

/// What a device does with an incoming P0 while its own P0 is unanswered.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum TieBreak {
    /// Close the own outgoing link and answer the incoming P0.
    AnswerIncoming,
    CloseIncoming,
    CloseBoth,
}

/// Compares the public `r` values as unsigned big-endian integers.
pub(crate) fn tie_break(own: &[u8; 16], incoming: &[u8; 16]) -> TieBreak {
    match incoming.cmp(own) {
        Ordering::Greater => TieBreak::AnswerIncoming,
        Ordering::Less => TieBreak::CloseIncoming,
        Ordering::Equal => TieBreak::CloseBoth,
    }
}

/// Rolling-hour ledgers on the monotonic clock; not persisted (ADR 0022).
#[derive(Debug, Default)]
pub(crate) struct Admission {
    attempts: VecDeque<u64>,
    admitted: VecDeque<u64>,
    failures: Vec<Failures>,
}

/// The failed attempts with one address, kept until 1 h after its back-off ends.
#[derive(Debug)]
struct Failures {
    address: Vec<u8>,
    transport: u32,
    forgiven: bool,
    refusals: u8,
    until_ms: u64,
}

impl Admission {
    /// Whether a pairing attempt with `address` may start or be answered now.
    pub(crate) fn allows(&mut self, now_ms: u64, neighbours: usize, address: &[u8]) -> bool {
        let expired = |&time: &u64| now_ms.saturating_sub(time) >= HOUR_MS;
        while self.attempts.front().is_some_and(expired) {
            self.attempts.pop_front();
        }
        while self.admitted.front().is_some_and(expired) {
            self.admitted.pop_front();
        }
        self.forget(now_ms);
        self.attempts.len() < MAX_ATTEMPTS_PER_HOUR
            && self.admitted.len() < MAX_ADMITTED_PER_HOUR
            && neighbours < MAX_NEIGHBOURS
            && !self.backed_off(now_ms, address)
    }

    fn backed_off(&self, now_ms: u64, address: &[u8]) -> bool {
        self.failures
            .iter()
            .any(|failures| failures.address == address && failures.until_ms > now_ms)
    }

    fn forget(&mut self, now_ms: u64) {
        self.failures
            .retain(|failures| now_ms.saturating_sub(failures.until_ms) < HOUR_MS);
    }

    pub(crate) fn record_attempt(&mut self, now_ms: u64) {
        self.attempts.push_back(now_ms);
    }

    /// Uncounts the attempt recorded at `attempt_ms`; a BUSY refusal ran no crypto.
    pub(crate) fn refund_attempt(&mut self, attempt_ms: u64) {
        if let Some(index) = self.attempts.iter().rposition(|&time| time == attempt_ms) {
            self.attempts.remove(index);
        }
    }

    pub(crate) fn record_admitted(&mut self, now_ms: u64) {
        self.admitted.push_back(now_ms);
    }

    /// A link drop or deadline: 2 min after the first, doubling up to 1 h.
    pub(crate) fn transport_failure(&mut self, now_ms: u64, address: &[u8]) {
        let failures = self.failures_of(now_ms, address);
        failures.transport += 1;
        let back_off = BASE_BACK_OFF_MS << (failures.transport - 1).min(5);
        failures.until_ms = failures.until_ms.max(now_ms + back_off.min(HOUR_MS));
    }

    /// A link drop mid-pairing; the first with no earlier failure is forgiven
    /// (spec §5.6, ADR 0040).
    pub(crate) fn link_dropped(&mut self, now_ms: u64, address: &[u8]) {
        let failures = self.failures_of(now_ms, address);
        if failures.transport == 0 && !failures.forgiven {
            failures.forgiven = true;
        } else {
            self.transport_failure(now_ms, address);
        }
    }

    /// A malformed or invalid frame or value refuses `address` for 1 h.
    pub(crate) fn protocol_failure(&mut self, now_ms: u64, address: &[u8]) {
        self.failures_of(now_ms, address).until_ms = now_ms + HOUR_MS;
    }

    /// A non-matching read that the limits refused; the third refuses
    /// `address` for 1 h (spec §10.4). Refusals while backed off don't count.
    pub(crate) fn refused(&mut self, now_ms: u64, address: &[u8]) {
        if self.backed_off(now_ms, address) {
            return;
        }
        let failures = self.failures_of(now_ms, address);
        failures.refusals += 1;
        if failures.refusals == 3 {
            failures.refusals = 0;
            failures.until_ms = now_ms + HOUR_MS;
        }
    }

    /// A completed pairing forgets the failures with `address`.
    pub(crate) fn paired(&mut self, address: &[u8]) {
        self.failures.retain(|failures| failures.address != address);
    }

    fn failures_of(&mut self, now_ms: u64, address: &[u8]) -> &mut Failures {
        self.forget(now_ms);
        let index = match self
            .failures
            .iter()
            .position(|failures| failures.address == address)
        {
            Some(index) => index,
            None => {
                self.failures.push(Failures {
                    address: address.into(),
                    transport: 0,
                    forgiven: false,
                    refusals: 0,
                    until_ms: now_ms,
                });
                self.failures.len() - 1
            }
        };
        &mut self.failures[index]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const ADDRESS: &[u8] = b"addr-1";

    #[test]
    fn tie_break_compares_r_as_big_endian_integers() {
        let low = [0; 16];
        let mut high = [0; 16];
        high[0] = 1;
        let mut high_last_byte = [0; 16];
        high_last_byte[15] = 0xff;

        let decisions = [
            tie_break(&low, &high),
            tie_break(&high, &high_last_byte),
            tie_break(&high, &high),
        ];

        assert_eq!(
            decisions,
            [
                TieBreak::AnswerIncoming,
                TieBreak::CloseIncoming,
                TieBreak::CloseBoth
            ]
        );
    }

    #[test]
    fn refunding_removes_only_the_attempt_still_counted() {
        let mut admission = Admission::default();
        admission.record_attempt(0);
        admission.allows(HOUR_MS, 0, ADDRESS);
        for _ in 0..30 {
            admission.record_attempt(HOUR_MS);
        }

        admission.refund_attempt(0);
        let after_expired = admission.allows(HOUR_MS, 0, ADDRESS);
        admission.refund_attempt(HOUR_MS);
        let after_counted = admission.allows(HOUR_MS, 0, ADDRESS);

        assert_eq!([after_expired, after_counted], [false, true]);
    }

    #[test]
    fn thirty_attempts_per_rolling_hour_are_allowed() {
        let mut admission = Admission::default();
        for minute in 0..30 {
            admission.record_attempt(minute * 60_000);
        }

        let decisions = [
            admission.allows(HOUR_MS - 1, 0, ADDRESS),
            admission.allows(HOUR_MS, 0, ADDRESS),
        ];

        assert_eq!(decisions, [false, true]);
    }

    #[test]
    fn ten_admissions_per_rolling_hour_are_allowed() {
        let mut admission = Admission::default();
        for second in 0..10 {
            admission.record_admitted(second * 1000);
        }

        let decisions = [
            admission.allows(HOUR_MS - 1, 10, ADDRESS),
            admission.allows(HOUR_MS, 10, ADDRESS),
        ];

        assert_eq!(decisions, [false, true]);
    }

    #[test]
    fn admission_stops_at_256_neighbours() {
        let mut admission = Admission::default();

        let decisions = [
            admission.allows(0, MAX_NEIGHBOURS - 1, ADDRESS),
            admission.allows(0, MAX_NEIGHBOURS, ADDRESS),
        ];

        assert_eq!(decisions, [true, false]);
    }

    #[test]
    fn a_protocol_failure_backs_off_one_hour_and_others_do_not() {
        let mut admission = Admission::default();
        admission.protocol_failure(1_000, ADDRESS);

        let decisions = [
            admission.allows(1_000 + HOUR_MS - 1, 0, ADDRESS),
            admission.allows(1_000 + HOUR_MS - 1, 0, b"addr-2"),
            admission.allows(1_000 + HOUR_MS, 0, ADDRESS),
        ];

        assert_eq!(decisions, [false, true, true]);
    }

    #[test]
    fn transport_failures_back_off_two_minutes_doubling_up_to_one_hour() {
        let mut admission = Admission::default();
        let mut now = 0;
        let mut waits = Vec::new();

        for _ in 0..7 {
            admission.transport_failure(now, ADDRESS);
            let start = now;
            while !admission.allows(now, 0, ADDRESS) {
                now += 1_000;
            }
            waits.push((now - start) / 60_000);
        }

        assert_eq!(waits, [2, 4, 8, 16, 32, 60, 60]);
    }

    #[test]
    fn only_a_first_link_drop_with_no_earlier_failure_is_forgiven() {
        let mut admission = Admission::default();
        admission.link_dropped(0, ADDRESS);
        let after_first = admission.allows(0, 0, ADDRESS);
        admission.link_dropped(0, ADDRESS);
        let after_second = admission.allows(BASE_BACK_OFF_MS - 1, 0, ADDRESS);
        admission.transport_failure(0, b"addr-2");
        admission.link_dropped(BASE_BACK_OFF_MS, b"addr-2");

        let decisions = [
            after_first,
            after_second,
            admission.allows(BASE_BACK_OFF_MS, 0, ADDRESS),
            admission.allows(3 * BASE_BACK_OFF_MS - 1, 0, b"addr-2"),
        ];

        assert_eq!(decisions, [true, false, true, false]);
    }

    #[test]
    fn a_forgiven_drop_is_forgotten_after_one_hour_or_a_pairing() {
        let mut admission = Admission::default();
        admission.link_dropped(0, ADDRESS);
        admission.link_dropped(0, b"addr-2");
        admission.paired(b"addr-2");

        admission.link_dropped(HOUR_MS, ADDRESS);
        admission.link_dropped(HOUR_MS, b"addr-2");

        assert!(admission.allows(HOUR_MS, 0, ADDRESS));
        assert!(admission.allows(HOUR_MS, 0, b"addr-2"));
    }

    #[test]
    fn transport_failures_are_forgotten_one_hour_after_the_back_off_ends() {
        let mut admission = Admission::default();
        let later = BASE_BACK_OFF_MS + HOUR_MS;
        admission.transport_failure(0, ADDRESS);
        admission.transport_failure(0, b"addr-2");
        admission.transport_failure(BASE_BACK_OFF_MS, b"addr-2");

        admission.transport_failure(later, ADDRESS);
        admission.transport_failure(later, b"addr-2");

        let decisions = [
            admission.allows(later + BASE_BACK_OFF_MS, 0, ADDRESS),
            admission.allows(later + BASE_BACK_OFF_MS, 0, b"addr-2"),
        ];

        assert_eq!(decisions, [true, false]);
    }

    #[test]
    fn a_successful_pairing_resets_the_transport_failures() {
        let mut admission = Admission::default();
        admission.transport_failure(0, ADDRESS);
        admission.transport_failure(0, ADDRESS);

        admission.paired(ADDRESS);
        admission.transport_failure(0, ADDRESS);

        assert!(admission.allows(BASE_BACK_OFF_MS, 0, ADDRESS));
    }

    #[test]
    fn a_transport_failure_does_not_shorten_a_protocol_back_off() {
        let mut admission = Admission::default();
        admission.protocol_failure(0, ADDRESS);

        admission.transport_failure(0, ADDRESS);

        assert!(!admission.allows(HOUR_MS - 1, 0, ADDRESS));
    }

    #[test]
    fn three_refusals_back_off_one_hour() {
        let mut admission = Admission::default();
        admission.refused(0, ADDRESS);
        admission.refused(0, ADDRESS);
        let after_two = admission.allows(0, 0, ADDRESS);

        admission.refused(1_000, ADDRESS);

        let decisions = [
            admission.allows(1_000 + HOUR_MS - 1, 0, ADDRESS),
            admission.allows(1_000 + HOUR_MS, 0, ADDRESS),
        ];
        assert!(after_two);
        assert_eq!(decisions, [false, true]);
    }

    #[test]
    fn refusals_while_backed_off_do_not_count() {
        let mut admission = Admission::default();
        admission.transport_failure(0, ADDRESS);

        for _ in 0..3 {
            admission.refused(0, ADDRESS);
        }
        admission.refused(BASE_BACK_OFF_MS, ADDRESS);

        assert!(admission.allows(BASE_BACK_OFF_MS, 0, ADDRESS));
    }
}
