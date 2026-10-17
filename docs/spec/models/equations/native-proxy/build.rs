use std::{env, error::Error, io, process::Command};

fn main() -> Result<(), Box<dyn Error>> {
    let status = Command::new("python3")
        .arg("inventory.py")
        .arg(env::var("OUT_DIR")?)
        .status()?;
    if !status.success() {
        return Err(io::Error::other("reviewed inventory generation failed").into());
    }
    Ok(())
}
