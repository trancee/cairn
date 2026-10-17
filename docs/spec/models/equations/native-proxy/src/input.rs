use std::io::Read;

use crate::{
    error::{Error, Result},
    unix,
};

pub(crate) struct Input {
    pending: Vec<u8>,
    eof: bool,
}

impl Input {
    pub(crate) fn new() -> Self {
        Self {
            pending: Vec::new(),
            eof: false,
        }
    }

    pub(crate) fn line(&mut self) -> Result<Option<Vec<u8>>> {
        loop {
            if unix::interrupted_now() {
                return Err(Error::Interrupted);
            }
            if let Some(end) = self.pending.iter().position(|byte| *byte == b'\n') {
                return Ok(Some(self.pending.drain(..=end).collect()));
            }
            if self.eof {
                return Ok(if self.pending.is_empty() {
                    None
                } else {
                    Some(std::mem::take(&mut self.pending))
                });
            }
            let mut fds = [unix::PollFd {
                fd: 0,
                events: 1,
                revents: 0,
            }];
            unix::ready(&mut fds, -1, true)?;
            let mut buffer = [0; 8096];
            let count = std::io::stdin().read(&mut buffer)?;
            self.eof = count == 0;
            self.pending.extend_from_slice(&buffer[..count]);
        }
    }
}
