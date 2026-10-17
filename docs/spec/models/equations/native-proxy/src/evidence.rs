use std::{
    env,
    fs::{File, OpenOptions},
    io::Write,
    os::unix::fs::OpenOptionsExt,
    path::Path,
};

use crate::{
    error::{Error::Rejected, Result},
    query::Kind,
};

pub(crate) fn open(variable: &str) -> Result<Option<File>> {
    let Some(destination) = env::var_os(variable).filter(|value| !value.is_empty()) else {
        return Ok(None);
    };
    if !Path::new(&destination).is_absolute() {
        return Err(Rejected("native evidence report: expected absolute path"));
    }
    #[cfg(target_os = "macos")]
    let flags = 0x100 | 0x4; // O_NOFOLLOW | O_NONBLOCK, Darwin.
    #[cfg(target_os = "linux")]
    let flags = 0x20000 | 0x800; // O_NOFOLLOW | O_NONBLOCK, Linux.
    let file = OpenOptions::new()
        .append(true)
        .create(true)
        .mode(0o600)
        .custom_flags(flags)
        .open(destination)
        .map_err(|_| Rejected("native evidence report: I/O failure"))?;
    if !file
        .metadata()
        .map_err(|_| Rejected("native evidence report: I/O failure"))?
        .is_file()
    {
        return Err(Rejected("native evidence report: expected regular file"));
    }
    Ok(Some(file))
}

pub(crate) fn write(file: &mut File, bytes: &[u8]) -> Result<()> {
    let count = file
        .write(bytes)
        .map_err(|_| Rejected("native evidence report: I/O failure"))?;
    if count != bytes.len() {
        return Err(Rejected("native evidence report: incomplete write"));
    }
    Ok(())
}

fn encoded(event: &str, field: Option<(&str, &str)>) -> Vec<u8> {
    let mut line = format!("{{\"event\": \"{event}\", \"pid\": {}", std::process::id());
    if let Some((key, value)) = field {
        line.push_str(&format!(", \"{key}\": \"{value}\""));
    }
    line.push_str("}\n");
    line.into_bytes()
}

pub fn record(event: &str, field: Option<(&str, &str)>) -> Result<()> {
    if let Some(mut file) = open("CAIRN_MAUDE_GUARD_REPORT")? {
        let written = write(&mut file, &encoded(event, field));
        let closed = crate::unix::close_file(file)
            .map_err(|_| Rejected("native evidence report: I/O failure"));
        written.and(closed)?;
    }
    Ok(())
}

pub enum OperationEvent {
    Begin,
    Accepted,
}

pub struct Journal {
    file: Option<File>,
    pending: Vec<u8>,
    records: [[Option<Vec<u8>>; 4]; 2],
}

impl Journal {
    pub fn new() -> Self {
        Self {
            file: None,
            pending: Vec::new(),
            records: Default::default(),
        }
    }

    pub fn record(&mut self, event: OperationEvent, kind: Kind) -> Result<()> {
        if self.file.is_none() {
            self.file = open("CAIRN_MAUDE_GUARD_REPORT")?;
        }
        if self.file.is_none() {
            return Ok(());
        }
        let (name, event_index) = match event {
            OperationEvent::Begin => ("begin", 0),
            OperationEvent::Accepted => ("accepted", 1),
        };
        let kind_index = match kind {
            Kind::Reduce => 0,
            Kind::Unify => 1,
            Kind::Match => 2,
            Kind::Variants => 3,
        };
        let record = self.records[event_index][kind_index]
            .get_or_insert_with(|| encoded(name, Some(("kind", kind.name()))));
        self.pending.extend_from_slice(record);
        if self.pending.len() >= 16_384 {
            self.flush()?;
        }
        Ok(())
    }

    fn flush(&mut self) -> Result<()> {
        if !self.pending.is_empty() {
            let file = self
                .file
                .as_mut()
                .ok_or(Rejected("native evidence report: missing descriptor"))?;
            write(file, &self.pending)?;
            self.pending.clear();
        }
        Ok(())
    }

    pub fn close(&mut self) -> Result<()> {
        let result = self.flush();
        let closed = if let Some(file) = self.file.take() {
            crate::unix::close_file(file)
                .map_err(|_| Rejected("native evidence report: I/O failure"))
        } else {
            Ok(())
        };
        result.and(closed)
    }
}
