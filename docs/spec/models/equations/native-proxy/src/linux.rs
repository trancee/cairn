use std::{
    fs::File,
    io,
    os::fd::{AsRawFd, FromRawFd},
    ptr,
};

use crate::{
    error::{Error, Result},
    unix::{self, PollFd},
};

const CLOSE_ON_EXEC: i32 = 0x80000;
const ADD: i32 = 1;
const DELETE: i32 = 2;
const INPUT: u32 = 1;

// Linux's eventpoll.h packs epoll_event on x86-64, but not other architectures.
#[cfg_attr(target_arch = "x86_64", repr(C, packed))]
#[cfg_attr(not(target_arch = "x86_64"), repr(C))]
#[derive(Clone, Copy)]
struct Event {
    events: u32,
    index: u64,
}

unsafe extern "C" {
    fn epoll_create1(flags: i32) -> i32;
    fn epoll_ctl(descriptor: i32, operation: i32, target: i32, event: *mut Event) -> i32;
    fn epoll_wait(descriptor: i32, events: *mut Event, count: i32, timeout: i32) -> i32;
}

pub struct Readiness {
    file: File,
}

impl Readiness {
    pub fn new(descriptors: &[PollFd; 2]) -> Result<Self> {
        // The flag is Linux O_CLOEXEC; successful creation transfers a fresh owned FD.
        let descriptor = unsafe { epoll_create1(CLOSE_ON_EXEC) };
        if descriptor < 0 {
            return Err(io::Error::last_os_error().into());
        }
        let readiness = Self {
            // epoll_create1 returned this live FD, not an alias of an existing owner.
            file: unsafe { File::from_raw_fd(descriptor) },
        };
        for (index, target) in [(0, descriptors[0].fd), (1, descriptors[1].fd)] {
            let mut event = Event {
                events: INPUT,
                index,
            };
            // Both pipe FDs remain owned by Native; Event has Linux's target ABI.
            if unsafe { epoll_ctl(descriptor, ADD, target, &mut event) } < 0 {
                return Err(io::Error::last_os_error().into());
            }
        }
        Ok(readiness)
    }

    pub fn wait(&self, descriptors: &mut [PollFd; 2]) -> Result<()> {
        let mut events = [Event {
            events: 0,
            index: 0,
        }; 2];
        loop {
            if unix::interrupted_now() {
                return Err(Error::Interrupted);
            }
            // The owned queue and two live ABI-matched output slots remain valid.
            let count = unsafe { epoll_wait(self.file.as_raw_fd(), events.as_mut_ptr(), 2, -1) };
            if count < 0 {
                let error = io::Error::last_os_error();
                if error.kind() == io::ErrorKind::Interrupted {
                    continue;
                }
                return Err(error.into());
            }
            for event in events.iter().take(count as usize) {
                match event.index {
                    0 => descriptors[0].revents = 1,
                    1 => descriptors[1].revents = 1,
                    _ => return Err(Error::Rejected("native process: invalid readiness event")),
                }
            }
            return Ok(());
        }
    }

    pub fn remove(&self, descriptor: i32) -> Result<()> {
        // Linux ignores the event pointer for DELETE; Native still owns the pipe.
        if unsafe { epoll_ctl(self.file.as_raw_fd(), DELETE, descriptor, ptr::null_mut()) } < 0 {
            return Err(io::Error::last_os_error().into());
        }
        Ok(())
    }

    pub fn close(self) -> Result<()> {
        unix::close_file(self.file)
    }
}
