use crate::{
    error::{Error::Rejected, Result},
    syntax::{Term, space, term, trim},
};

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Reduce,
    Unify,
    Match,
    Variants,
}

impl Kind {
    pub fn name(self) -> &'static str {
        match self {
            Self::Reduce => "reduce",
            Self::Unify => "unify",
            Self::Match => "match",
            Self::Variants => "variants",
        }
    }
}

pub struct Query {
    pub kind: Kind,
    pub terms: Vec<Term>,
}

pub fn validate(command: &str) -> Result<Query> {
    if !command.is_ascii() {
        return Err(Rejected("native query: non-ASCII syntax"));
    }
    let command = trim(command)
        .strip_suffix('.')
        .map(trim)
        .ok_or(Rejected("native query: unsupported command"))?;
    let (kind, body) = if let Some(body) = command
        .strip_prefix("reduce")
        .filter(|body| body.as_bytes().first().is_some_and(|byte| space(*byte)))
    {
        (Kind::Reduce, trim(body))
    } else {
        let mut found = None;
        for (prefix, kind) in [
            ("unify in MSG", Kind::Unify),
            ("match in MSG", Kind::Match),
            ("get variants in MSG", Kind::Variants),
        ] {
            if let Some(body) = command
                .strip_prefix(prefix)
                .map(trim)
                .and_then(|body| body.strip_prefix(':'))
            {
                found = Some((kind, trim(body)));
                break;
            }
        }
        found.ok_or(Rejected("native query: unsupported command"))?
    };
    let mut terms = Vec::new();
    if matches!(kind, Kind::Reduce | Kind::Variants) {
        terms.push(term(body, true)?);
    } else {
        let equations: Vec<_> = if kind == Kind::Unify {
            body.split("/\\").collect()
        } else {
            vec![body]
        };
        for equation in equations {
            let sides: Vec<_> = equation
                .split(if kind == Kind::Unify { "=?" } else { "<=?" })
                .collect();
            if sides.len() != 2 {
                return Err(Rejected("native query: malformed equation"));
            }
            for side in sides {
                terms.push(term(side, true)?);
            }
        }
    }
    Ok(Query { kind, terms })
}
