use std::{env, fs::File, time::Instant};

use crate::{
    error::{Error::Rejected, Result},
    evidence, unix,
};

#[derive(Clone, Copy)]
pub(crate) enum Phase {
    Input,
    QueryValidation,
    Journal,
    NativeIo,
    ReplyValidation,
    Forwarding,
}

const PHASES: [Phase; 6] = [
    Phase::Input,
    Phase::QueryValidation,
    Phase::Journal,
    Phase::NativeIo,
    Phase::ReplyValidation,
    Phase::Forwarding,
];

impl Phase {
    fn name(self) -> &'static str {
        match self {
            Self::Input => "input",
            Self::QueryValidation => "query_validation",
            Self::Journal => "journal",
            Self::NativeIo => "native_io",
            Self::ReplyValidation => "reply_validation",
            Self::Forwarding => "forwarding",
        }
    }
}

#[derive(Clone, Copy, Default)]
struct Counters {
    calls: u64,
    cpu_nanoseconds: u64,
    wall_nanoseconds: u64,
}

struct Capture {
    file: File,
    cpu_started: u64,
    wall_started: Instant,
    phases: [Counters; PHASES.len()],
}

pub(crate) struct Profile {
    capture: Option<Capture>,
}

#[cfg(any(all(target_os = "linux", target_pointer_width = "64"), test))]
fn nanoseconds(status: i32, seconds: i64, fraction: i64) -> Result<u64> {
    if status != 0 {
        return Err(Rejected("native CPU profile: clock unavailable"));
    }
    if seconds < 0 || !(0..1_000_000_000).contains(&fraction) {
        return Err(Rejected("native CPU profile: invalid clock"));
    }
    u64::try_from(seconds)
        .ok()
        .and_then(|value| value.checked_mul(1_000_000_000))
        .and_then(|value| {
            u64::try_from(fraction)
                .ok()
                .and_then(|fraction| value.checked_add(fraction))
        })
        .ok_or(Rejected("native CPU profile: clock overflow"))
}

#[cfg(all(target_os = "linux", target_pointer_width = "64"))]
fn cpu_time() -> Result<u64> {
    #[repr(C)]
    struct Timespec {
        seconds: i64,
        nanoseconds: i64,
    }
    unsafe extern "C" {
        fn clock_gettime(clock: i32, output: *mut Timespec) -> i32;
    }
    let mut time = Timespec {
        seconds: 0,
        nanoseconds: 0,
    };
    // Linux LP64 timespec has two signed 64-bit fields; 3 is CLOCK_THREAD_CPUTIME_ID.
    let status = unsafe { clock_gettime(3, &mut time) };
    nanoseconds(status, time.seconds, time.nanoseconds)
}

#[cfg(not(all(target_os = "linux", target_pointer_width = "64")))]
fn cpu_time() -> Result<u64> {
    Err(Rejected(
        "native CPU profiling requires 64-bit native Linux",
    ))
}

fn wall_time(started: Instant) -> Result<u64> {
    u64::try_from(started.elapsed().as_nanos())
        .map_err(|_| Rejected("native CPU profile: clock overflow"))
}

impl Profile {
    pub(crate) fn new() -> Result<Self> {
        let enabled =
            env::var_os("CAIRN_MAUDE_PHASE_REPORT").is_some_and(|value| !value.is_empty());
        let capture = if enabled {
            let cpu_started = cpu_time()?;
            let wall_started = Instant::now();
            let file = evidence::open("CAIRN_MAUDE_PHASE_REPORT")?
                .ok_or(Rejected("native CPU profile: missing destination"))?;
            Some(Capture {
                file,
                cpu_started,
                wall_started,
                phases: [Counters::default(); PHASES.len()],
            })
        } else {
            None
        };
        Ok(Self { capture })
    }

    pub(crate) fn measure<T>(
        &mut self,
        phase: Phase,
        action: impl FnOnce() -> Result<T>,
    ) -> Result<T> {
        let Some(capture) = self.capture.as_mut() else {
            return action();
        };
        let cpu_started = cpu_time()?;
        let wall_started = Instant::now();
        let result = action();
        let cpu_nanoseconds = cpu_time()?
            .checked_sub(cpu_started)
            .ok_or(Rejected("native CPU profile: nonmonotonic clock"))?;
        let wall_nanoseconds = wall_time(wall_started)?;
        let previous = capture.phases[phase as usize];
        let add = |left: u64, right| {
            left.checked_add(right)
                .ok_or(Rejected("native CPU profile: counter overflow"))
        };
        capture.phases[phase as usize] = Counters {
            calls: add(previous.calls, 1)?,
            cpu_nanoseconds: add(previous.cpu_nanoseconds, cpu_nanoseconds)?,
            wall_nanoseconds: add(previous.wall_nanoseconds, wall_nanoseconds)?,
        };
        result
    }

    pub(crate) fn finish(self) -> Result<()> {
        let Some(mut capture) = self.capture else {
            return Ok(());
        };
        let cpu = cpu_time()?
            .checked_sub(capture.cpu_started)
            .ok_or(Rejected("native CPU profile: nonmonotonic clock"))?;
        let wall = wall_time(capture.wall_started)?;
        let phases = PHASES
            .into_iter()
            .map(|phase| {
                let counters = capture.phases[phase as usize];
                format!(
                    "\"{}\":{{\"calls\":{},\"cpu_nanoseconds\":{},\"wall_nanoseconds\":{}}}",
                    phase.name(),
                    counters.calls,
                    counters.cpu_nanoseconds,
                    counters.wall_nanoseconds,
                )
            })
            .collect::<Vec<_>>()
            .join(",");
        let record = format!(
            "{{\"pid\":{},\"interactive_cpu_nanoseconds\":{cpu},\
             \"interactive_wall_nanoseconds\":{wall},\"phases\":{{{phases}}}}}\n",
            std::process::id(),
        );
        let written = evidence::write(&mut capture.file, record.as_bytes());
        let closed = unix::close_file(capture.file)
            .map_err(|_| Rejected("native evidence report: I/O failure"));
        written.and(closed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clock_values_preserve_nanosecond_precision() {
        let result = nanoseconds(0, 3, 42);

        assert_eq!(result.unwrap(), 3_000_000_042);
    }

    #[test]
    fn unavailable_malformed_and_overflowing_clocks_reject() {
        for (status, seconds, fraction, reason) in [
            (-1, 0, 0, "clock unavailable"),
            (0, -1, 0, "invalid clock"),
            (0, 0, -1, "invalid clock"),
            (0, 0, 1_000_000_000, "invalid clock"),
            (0, i64::MAX, 0, "clock overflow"),
        ] {
            let result = nanoseconds(status, seconds, fraction);

            assert!(result.unwrap_err().reason().contains(reason));
        }
    }

    #[cfg(all(target_os = "linux", target_pointer_width = "64"))]
    #[test]
    fn actual_thread_cpu_clock_is_monotonic() {
        let before = cpu_time().unwrap();

        let after = cpu_time().unwrap();

        assert!(after >= before);
    }
}
