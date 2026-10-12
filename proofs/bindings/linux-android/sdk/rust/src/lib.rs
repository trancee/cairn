#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum ArithmeticError {
    #[error("addition overflow")]
    Overflow,
}

#[uniffi::export]
pub fn checked_add(lhs: i32, rhs: i32) -> Result<i32, ArithmeticError> {
    lhs.checked_add(rhs).ok_or(ArithmeticError::Overflow)
}

#[derive(uniffi::Object)]
pub struct Greeter {
    greeting: String,
}

#[uniffi::export]
impl Greeter {
    #[uniffi::constructor]
    pub fn new(greeting: String) -> Self {
        Self { greeting }
    }

    pub fn greet(&self, name: String) -> String {
        format!("{}, {name}!", self.greeting)
    }
}

uniffi::setup_scaffolding!();
