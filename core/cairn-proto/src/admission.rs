//! Automatic admission limits and the P0 tie-break (spec §5.6, ADR 0021).

use alloc::collections::VecDeque;
use alloc::vec::Vec;
use core::cmp::Ordering;

const HOUR_MS: u64 = 3_600_000;
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
    back_off: Vec<(Vec<u8>, u64)>,
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
        self.back_off.retain(|&(_, until)| until > now_ms);
        self.attempts.len() < MAX_ATTEMPTS_PER_HOUR
            && self.admitted.len() < MAX_ADMITTED_PER_HOUR
            && neighbours < MAX_NEIGHBOURS
            && !self
                .back_off
                .iter()
                .any(|(backed_off, _)| backed_off == address)
    }

    pub(crate) fn record_attempt(&mut self, now_ms: u64) {
        self.attempts.push_back(now_ms);
    }

    pub(crate) fn record_admitted(&mut self, now_ms: u64) {
        self.admitted.push_back(now_ms);
    }

    /// Refuses `address` for one hour after a failed or refused attempt.
    pub(crate) fn back_off(&mut self, now_ms: u64, address: &[u8]) {
        self.back_off
            .retain(|(backed_off, _)| backed_off != address);
        self.back_off.push((address.into(), now_ms + HOUR_MS));
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
    fn a_backed_off_address_waits_one_hour_and_others_do_not() {
        let mut admission = Admission::default();
        admission.back_off(1_000, ADDRESS);

        let decisions = [
            admission.allows(1_000 + HOUR_MS - 1, 0, ADDRESS),
            admission.allows(1_000 + HOUR_MS - 1, 0, b"addr-2"),
            admission.allows(1_000 + HOUR_MS, 0, ADDRESS),
        ];

        assert_eq!(decisions, [false, true, true]);
    }
}
