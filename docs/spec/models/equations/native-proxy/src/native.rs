use std::{
    io::{Read, Write},
    os::{fd::AsRawFd, unix::process::ExitStatusExt},
    process::{Child, Command, ExitStatus, Stdio},
    time::{Duration, Instant},
};

use crate::{
    error::{Error::Rejected, Result},
    unix::{self, PollFd},
};

pub const PROMPT: &[u8] = b"Maude> ";

pub struct Native {
    child: Child,
    errors_open: bool,
    #[cfg(target_os = "linux")]
    readiness: Option<crate::linux::Readiness>,
}

impl Native {
    pub fn spawn(executable: &std::path::Path, arguments: &[String]) -> Result<Self> {
        Ok(Self {
            child: Command::new(executable)
                .args(arguments)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()?,
            errors_open: true,
            #[cfg(target_os = "linux")]
            readiness: None,
        })
    }

    pub fn write(&mut self, bytes: &[u8]) -> Result<()> {
        let input = self
            .child
            .stdin
            .as_mut()
            .ok_or(Rejected("native process: missing input pipe"))?;
        input.write_all(bytes)?;
        input.flush()?;
        Ok(())
    }

    pub fn reply(&mut self) -> Result<Vec<u8>> {
        let mut output = Vec::new();
        loop {
            let mut fds = [
                PollFd {
                    fd: if self.errors_open {
                        self.child
                            .stderr
                            .as_ref()
                            .ok_or(Rejected("native process: missing output pipe"))?
                            .as_raw_fd()
                    } else {
                        -1
                    },
                    events: 1,
                    revents: 0,
                },
                PollFd {
                    fd: self
                        .child
                        .stdout
                        .as_ref()
                        .ok_or(Rejected("native process: missing output pipe"))?
                        .as_raw_fd(),
                    events: 1,
                    revents: 0,
                },
            ];
            #[cfg(target_os = "linux")]
            self.readiness(&fds)?.wait(&mut fds)?;
            #[cfg(target_os = "macos")]
            unix::ready(&mut fds, -1, true)?;
            let mut buffer = [0; 8096];
            if fds[0].revents != 0 {
                let count = self
                    .child
                    .stderr
                    .as_mut()
                    .ok_or(Rejected("native process: missing output pipe"))?
                    .read(&mut buffer)?;
                if count != 0 {
                    return Err(Rejected("native process: stderr diagnostic"));
                }
                #[cfg(target_os = "linux")]
                self.readiness(&fds)?.remove(fds[0].fd)?;
                self.errors_open = false;
            }
            if fds[1].revents != 0 {
                let count = self
                    .child
                    .stdout
                    .as_mut()
                    .ok_or(Rejected("native process: missing output pipe"))?
                    .read(&mut buffer)?;
                if count == 0 {
                    return Err(Rejected("native process: premature EOF"));
                }
                output.extend_from_slice(&buffer[..count]);
                if output.ends_with(PROMPT) {
                    output.truncate(output.len() - PROMPT.len());
                    return Ok(output);
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    fn readiness(&mut self, descriptors: &[PollFd; 2]) -> Result<&mut crate::linux::Readiness> {
        match self.readiness {
            Some(ref mut readiness) => Ok(readiness),
            None => Ok(self
                .readiness
                .insert(crate::linux::Readiness::new(descriptors)?)),
        }
    }

    pub fn capture(
        &mut self,
        seconds: u64,
        allow_kill: bool,
    ) -> Result<(ExitStatus, Vec<u8>, Vec<u8>)> {
        self.child.stdin.take();
        let deadline = Instant::now() + Duration::from_secs(seconds);
        let mut output = Vec::new();
        let mut errors = Vec::new();
        let mut output_open = true;
        let mut errors_open = true;
        let mut killed = false;
        loop {
            let status = self.child.try_wait()?;
            if !output_open
                && !errors_open
                && let Some(status) = status
            {
                return Ok((status, output, errors));
            }
            if Instant::now() >= deadline && !killed {
                self.child.kill()?;
                self.child.wait()?;
                if !allow_kill {
                    return Err(Rejected("native process: I/O or version failure"));
                }
                killed = true;
            }
            let mut fds = [
                PollFd {
                    fd: if errors_open {
                        self.child
                            .stderr
                            .as_ref()
                            .ok_or(Rejected("native process: missing output pipe"))?
                            .as_raw_fd()
                    } else {
                        -1
                    },
                    events: 1,
                    revents: 0,
                },
                PollFd {
                    fd: if output_open {
                        self.child
                            .stdout
                            .as_ref()
                            .ok_or(Rejected("native process: missing output pipe"))?
                            .as_raw_fd()
                    } else {
                        -1
                    },
                    events: 1,
                    revents: 0,
                },
            ];
            let timeout = if killed {
                0
            } else if !output_open && !errors_open {
                1
            } else {
                50
            };
            if !unix::ready(&mut fds, timeout, !allow_kill)? {
                if killed {
                    return Err(Rejected("native shutdown: unexpected exit or diagnostic"));
                }
                continue;
            }
            let mut buffer = [0; 8096];
            if fds[0].revents != 0 {
                let count = self
                    .child
                    .stderr
                    .as_mut()
                    .ok_or(Rejected("native process: missing output pipe"))?
                    .read(&mut buffer)?;
                errors_open = count != 0;
                errors.extend_from_slice(&buffer[..count]);
            }
            if fds[1].revents != 0 {
                let count = self
                    .child
                    .stdout
                    .as_mut()
                    .ok_or(Rejected("native process: missing output pipe"))?
                    .read(&mut buffer)?;
                output_open = count != 0;
                output.extend_from_slice(&buffer[..count]);
            }
        }
    }

    pub fn shutdown(&mut self) -> Result<()> {
        if self.child.try_wait()?.is_none() {
            unix::terminate(self.child.id())?;
        }
        let (status, output, errors) = self.capture(5, true)?;
        if !(status.success() || matches!(status.signal(), Some(15 | 9)))
            || output.iter().any(|byte| !crate::syntax::space(*byte))
            || !errors.is_empty()
        {
            return Err(Rejected("native shutdown: unexpected exit or diagnostic"));
        }
        #[cfg(target_os = "linux")]
        if let Some(readiness) = self.readiness.take() {
            readiness.close()?;
        }
        Ok(())
    }
}

impl Drop for Native {
    fn drop(&mut self) {
        match self.child.try_wait() {
            Ok(Some(_)) => {}
            Ok(None) => {
                if self.child.kill().is_err() || self.child.wait().is_err() {
                    eprintln!("FAIL: native shutdown cleanup failed");
                }
            }
            Err(_) => eprintln!("FAIL: native shutdown status failed"),
        }
    }
}
