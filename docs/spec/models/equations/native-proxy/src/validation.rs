use crate::{
    error::{Error::Rejected, Result},
    query::{self, Kind, Query},
    reply,
};

const MAX_CACHED_BYTES: usize = 16 * 1024;

struct Exchange {
    command: Option<String>,
    query: Query,
    reply: Option<String>,
}

#[derive(Default)]
pub struct Validator {
    exchange: Option<Exchange>,
}

impl Validator {
    pub fn query(&mut self, command: &str) -> Result<Kind> {
        if let Some(exchange) = &self.exchange
            && exchange.command.as_deref() == Some(command)
        {
            return Ok(exchange.query.kind);
        }
        self.exchange = None;
        let query = query::validate(command)?;
        let kind = query.kind;
        self.exchange = Some(Exchange {
            command: (command.len() <= MAX_CACHED_BYTES).then(|| command.to_owned()),
            query,
            reply: None,
        });
        Ok(kind)
    }

    pub fn reply(&mut self, text: &str) -> Result<()> {
        let exchange = self
            .exchange
            .as_mut()
            .ok_or(Rejected("native query: missing validated query"))?;
        if exchange.reply.as_deref() != Some(text) {
            exchange.reply = None;
            reply::validate(&exchange.query, text)?;
            if exchange.command.is_some() && text.len() <= MAX_CACHED_BYTES {
                exchange.reply = Some(text.to_owned());
            }
        }
        if exchange.command.is_none() {
            self.exchange = None;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::Validator;

    #[test]
    fn reply_without_a_validated_query_rejects_explicitly() {
        let mut validator = Validator::default();

        let error = validator.reply("result Msg: tamXCroleA\n").unwrap_err();

        assert_eq!(error.reason(), "native query: missing validated query");
    }

    #[test]
    fn reply_after_a_rejected_query_cannot_reuse_the_previous_context() {
        let mut validator = Validator::default();
        validator.query("reduce tamXCroleA .").unwrap();
        validator.reply("result Msg: tamXCroleA\n").unwrap();
        assert!(validator.query("reduce tamXCunknown .").is_err());

        let error = validator.reply("result Msg: tamXCroleA\n").unwrap_err();

        assert_eq!(error.reason(), "native query: missing validated query");
    }
}
