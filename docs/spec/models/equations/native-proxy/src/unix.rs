use std::{
    fs::File,
    io,
    os::fd::{AsFd, IntoRawFd},
    sync::atomic::{AtomicBool, Ordering},
};

use crate::error::{Error, Result};

static INTERRUPTED: AtomicBool = AtomicBool::new(false);

#[repr(C)]
pub struct PollFd {
    pub fd: i32,
    pub events: i16,
    pub revents: i16,
}

#[cfg(target_os = "macos")]
type DescriptorCount = u32;
#[cfg(target_os = "linux")]
type DescriptorCount = usize;

unsafe extern "C" {
    fn poll(fds: *mut PollFd, count: DescriptorCount, timeout: i32) -> i32;
    fn signal(number: i32, handler: usize) -> usize;
    fn kill(pid: i32, number: i32) -> i32;
    fn close(fd: i32) -> i32;
}

extern "C" fn interrupted(_: i32) {
    INTERRUPTED.store(true, Ordering::SeqCst);
}

pub fn install_handlers() -> Result<()> {
    for number in [2, 15] {
        // POSIX signal uses a function pointer; the handler only stores a lock-free atomic.
        if unsafe { signal(number, interrupted as *const () as usize) } == usize::MAX {
            return Err(io::Error::last_os_error().into());
        }
    }
    Ok(())
}

pub fn interrupted_now() -> bool {
    INTERRUPTED.load(Ordering::SeqCst)
}

pub fn stdout_file() -> Result<File> {
    Ok(File::from(std::io::stdout().as_fd().try_clone_to_owned()?))
}

pub fn ready(fds: &mut [PollFd], timeout: i32, interruptible: bool) -> Result<bool> {
    loop {
        if interruptible && interrupted_now() {
            return Err(Error::Interrupted);
        }
        let count = DescriptorCount::try_from(fds.len())
            .map_err(|_| Error::Rejected("native process: descriptor overflow"))?;
        // repr(C), the platform's nfds_t, and the live slice match poll's ABI.
        let result = unsafe { poll(fds.as_mut_ptr(), count, timeout) };
        if result >= 0 {
            return Ok(result != 0);
        }
        let error = io::Error::last_os_error();
        if error.kind() != io::ErrorKind::Interrupted {
            return Err(error.into());
        }
    }
}

pub fn terminate(pid: u32) -> Result<()> {
    let pid = i32::try_from(pid).map_err(|_| Error::Rejected("native process: invalid PID"))?;
    // The caller owns this unreaped Child, so its PID cannot have been reused.
    if unsafe { kill(pid, 15) } == 0 {
        return Ok(());
    }
    let error = io::Error::last_os_error();
    if error.raw_os_error() == Some(3) {
        Ok(())
    } else {
        Err(error.into())
    }
}

pub fn close_file(file: File) -> Result<()> {
    // Transfer ownership before close; an interrupted close is never retried on a reused FD.
    if unsafe { close(file.into_raw_fd()) } == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error().into())
    }
}
