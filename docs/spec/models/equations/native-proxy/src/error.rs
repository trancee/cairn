#[derive(Debug)]
pub enum Error {
    Rejected(&'static str),
    Interrupted,
}

pub type Result<T> = std::result::Result<T, Error>;

impl From<std::io::Error> for Error {
    fn from(error: std::io::Error) -> Self {
        if error.kind() == std::io::ErrorKind::Interrupted && crate::unix::interrupted_now() {
            Self::Interrupted
        } else {
            Self::Rejected("native process: I/O or version failure")
        }
    }
}

impl Error {
    pub fn reason(&self) -> &'static str {
        match self {
            Self::Rejected(reason) => reason,
            Self::Interrupted => "native operation interrupted",
        }
    }
}
