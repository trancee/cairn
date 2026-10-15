mod error;
mod evidence;
mod native;
mod query;
mod reply;
mod syntax;
mod unix;

mod inventory {
    include!(concat!(env!("OUT_DIR"), "/inventory.rs"));
}

use error::{Error, Error::Rejected, Result};
use native::{Native, PROMPT};
use std::{
    collections::BTreeSet,
    env,
    fs::File,
    io::{Read, Write},
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::PathBuf,
    process::ExitCode,
};

const FLAGS: [&str; 5] = [
    "-interactive",
    "-no-tecla",
    "-no-banner",
    "-no-wrap",
    "-batch",
];
const SETUP: [&str; 3] = [
    "set show command off .",
    "set show timing off .",
    "set show stats off .",
];

struct Input {
    pending: Vec<u8>,
    eof: bool,
}

impl Input {
    fn new() -> Self {
        Self {
            pending: Vec::new(),
            eof: false,
        }
    }
    fn line(&mut self) -> Result<Option<Vec<u8>>> {
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

fn forward(output: &mut impl Write, mut reply: Vec<u8>) -> Result<()> {
    reply.extend_from_slice(PROMPT);
    output.write_all(&reply)?;
    output.flush()?;
    Ok(())
}

fn executable() -> Result<PathBuf> {
    let selected = env::var_os("CAIRN_MAUDE_BINARY").filter(|value| !value.is_empty());
    let selected = selected.unwrap_or_else(|| "maude".into());
    let selected = PathBuf::from(selected);
    let path = if selected.is_absolute() || selected.components().count() > 1 {
        selected
    } else {
        env::split_paths(&env::var_os("PATH").unwrap_or_default())
            .map(|directory| directory.join(&selected))
            .find(|path| {
                path.metadata().is_ok_and(|metadata| {
                    metadata.is_file() && metadata.permissions().mode() & 0o111 != 0
                })
            })
            .ok_or(Rejected("native process: missing or recursive executable"))?
    };
    let resolved = path.canonicalize()?;
    let current = env::current_exe()?.canonicalize()?;
    let metadata = resolved.metadata()?;
    let own_metadata = current.metadata()?;
    if resolved == current
        || metadata.dev() == own_metadata.dev() && metadata.ino() == own_metadata.ino()
    {
        return Err(Rejected("native process: missing or recursive executable"));
    }
    Ok(resolved)
}

fn module_valid(module: &str) -> Result<()> {
    fn normalized(text: &str) -> Vec<String> {
        syntax::lines(text)
            .map(|line| {
                line.split(syntax::space_char)
                    .filter(|part| !part.is_empty())
                    .collect::<Vec<_>>()
                    .join(" ")
            })
            .collect()
    }
    if !module.is_ascii() || normalized(module) != normalized(inventory::EXPECTED_MODULE) {
        return Err(Rejected("native module: unreviewed signature or equations"));
    }
    Ok(())
}

fn stream(
    native: &mut Native,
    journal: &mut evidence::Journal,
    ready: &mut bool,
    pending: &mut bool,
    consumer: &mut File,
) -> Result<()> {
    let greeting = native.reply()?;
    if greeting.iter().any(|byte| !syntax::space(*byte)) {
        return Err(Rejected("native process: unexpected greeting"));
    }
    forward(consumer, greeting)?;
    let mut input = Input::new();
    let mut setup = BTreeSet::new();
    let mut module = Vec::new();
    while let Some(line) = input.line()? {
        if !line.is_ascii() {
            return Err(Rejected("native command: non-ASCII syntax"));
        }
        let text =
            std::str::from_utf8(&line).map_err(|_| Rejected("native command: non-ASCII syntax"))?;
        let command = syntax::trim(text);
        if !module.is_empty() {
            module.extend_from_slice(&line);
            if command != "endfm" {
                continue;
            }
            module_valid(
                std::str::from_utf8(&module)
                    .map_err(|_| Rejected("native command: non-ASCII syntax"))?,
            )?;
            native.write(&module)?;
            let reply = native.reply()?;
            if reply.iter().any(|byte| !syntax::space(*byte)) {
                return Err(Rejected("native module: unexpected reply"));
            }
            module.clear();
            *ready = true;
            evidence::record("module", None)?;
            forward(consumer, reply)?;
            continue;
        }
        if SETUP.contains(&command) && !*ready {
            if !setup.insert(command.to_owned()) {
                return Err(Rejected("native setup: duplicate command"));
            }
            native.write(&line)?;
            let reply = native.reply()?;
            if reply.iter().any(|byte| !syntax::space(*byte)) {
                return Err(Rejected("native setup: unexpected reply"));
            }
            forward(consumer, reply)?;
            continue;
        }
        if command == "fmod MSG is" && !*ready && setup.len() == SETUP.len() {
            module.extend_from_slice(&line);
            continue;
        }
        if !*ready {
            return Err(Rejected("native command: missing reviewed module"));
        }
        let query = query::validate(command)?;
        journal.record("begin", query.kind.name())?;
        *pending = true;
        native.write(&line)?;
        let output = native.reply()?;
        let text =
            std::str::from_utf8(&output).map_err(|_| Rejected("native reply: non-ASCII syntax"))?;
        reply::validate(&query, text)?;
        journal.record("accepted", query.kind.name())?;
        *pending = false;
        forward(consumer, output)?;
    }
    if !module.is_empty() {
        return Err(Rejected("native module: truncated declaration"));
    }
    if !*ready {
        return Err(Rejected("native command: missing reviewed module"));
    }
    Ok(())
}

fn run(journal: &mut evidence::Journal, consumer: &mut File) -> Result<()> {
    unix::install_handlers()?;
    let executable = executable()?;
    let mut version = Native::spawn(&executable, &["--version".to_owned()])?;
    let (status, output, errors) = version.capture(30, false)?;
    if !status.success() || output.trim_ascii() != b"3.5.1" || !errors.is_empty() {
        return Err(Rejected("native process: expected Maude 3.5.1"));
    }
    evidence::record("version", Some(("source_id", inventory::SOURCE_ID)))?;
    let arguments: Vec<_> = env::args_os()
        .skip(1)
        .map(|argument| {
            argument
                .into_string()
                .map_err(|_| Rejected("native process: unsupported invocation"))
        })
        .collect::<Result<_>>()?;
    if arguments == ["--version"] {
        consumer.write_all(&output)?;
        consumer.flush()?;
        return Ok(());
    }
    if arguments.is_empty() {
        let mut input = Input::new();
        let mut command = Vec::new();
        while let Some(line) = input.line()? {
            command.extend_from_slice(&line);
        }
        if command != b"quit\n" {
            return Err(Rejected("native installation: unsupported input"));
        }
        let mut probe = Native::spawn(&executable, &[])?;
        probe.write(b"quit\n")?;
        let (status, output, errors) = probe.capture(30, false)?;
        if !status.success() || !errors.is_empty() {
            return Err(Rejected("native installation: failed probe"));
        }
        evidence::record("installation", None)?;
        consumer.write_all(&output)?;
        consumer.flush()?;
        return Ok(());
    }
    let flags: BTreeSet<_> = arguments.iter().map(String::as_str).collect();
    if arguments.len() != FLAGS.len() || flags != FLAGS.into_iter().collect() {
        return Err(Rejected("native process: unsupported invocation"));
    }
    let mut native = Native::spawn(&executable, &arguments)?;
    evidence::record("start", None)?;
    let mut ready = false;
    let mut pending = false;
    match stream(&mut native, journal, &mut ready, &mut pending, consumer) {
        Ok(()) => {}
        Err(Error::Interrupted) if ready && !pending => {}
        Err(error) => return Err(error),
    }
    native.shutdown()?;
    journal.close()?;
    evidence::record("shutdown", None)
}

fn main() -> ExitCode {
    let mut journal = evidence::Journal::new();
    let result = unix::stdout_file().and_then(|mut consumer| {
        let result = run(&mut journal, &mut consumer);
        result.and(unix::close_file(consumer))
    });
    let closed = journal.close();
    if let Err(error) = result.and(closed) {
        let reason = if evidence::record("failure", Some(("reason", error.reason()))).is_err() {
            "native evidence report: I/O failure"
        } else {
            error.reason()
        };
        eprintln!("FAIL: {reason}");
        let rejection = b"FAIL: Cairn Maude boundary rejected this operation.\n";
        if forward(&mut std::io::stdout().lock(), rejection.to_vec()).is_err() {
            eprintln!("FAIL: native consumer closed its input");
        }
        return ExitCode::FAILURE;
    }
    ExitCode::SUCCESS
}
