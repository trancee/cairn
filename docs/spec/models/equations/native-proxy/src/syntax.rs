use std::collections::BTreeSet;

use crate::{
    error::{Error::Rejected, Result},
    inventory::FUNCTIONS,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Sort {
    Pub,
    Fresh,
    Msg,
    Natural,
    Node,
    Top,
    KindNatural,
    KindMessage,
    KindFraming,
    Decimal,
}

impl Sort {
    pub fn named(name: &str) -> Option<Self> {
        match name {
            "Pub" => Some(Self::Pub),
            "Fresh" => Some(Self::Fresh),
            "Msg" => Some(Self::Msg),
            "TamNat" => Some(Self::Natural),
            "Node" => Some(Self::Node),
            "TOP" => Some(Self::Top),
            _ => None,
        }
    }

    fn kind(self) -> bool {
        matches!(
            self,
            Self::KindNatural | Self::KindMessage | Self::KindFraming
        )
    }

    fn message(self) -> bool {
        matches!(
            self,
            Self::Pub
                | Self::Fresh
                | Self::Msg
                | Self::Natural
                | Self::KindNatural
                | Self::KindMessage
        )
    }

    pub fn below(self, expected: Self) -> bool {
        self == expected
            || match expected {
                Self::Top => !self.kind() && self != Self::Decimal,
                Self::Msg => self.message() && !self.kind(),
                Self::KindNatural | Self::KindMessage => self.message(),
                Self::KindFraming => self != Self::Decimal,
                Self::Pub | Self::Fresh | Self::Natural | Self::Node | Self::Decimal => false,
            }
    }
}

pub fn space(byte: u8) -> bool {
    byte.is_ascii_whitespace() || (0x1c..=0x1f).contains(&byte)
}

pub fn trim(text: &str) -> &str {
    text.trim_matches(space_char)
}

pub fn space_char(character: char) -> bool {
    character.is_ascii() && space(character as u8)
}

pub fn lines(text: &str) -> impl Iterator<Item = &str> {
    text.split(['\n', '\r', '\x0b', '\x0c', '\x1c', '\x1d', '\x1e'])
        .map(trim)
        .filter(|line| !line.is_empty())
}

fn decimal(text: &str) -> bool {
    text == "0"
        || text
            .as_bytes()
            .first()
            .is_some_and(|b| matches!(b, b'1'..=b'9'))
            && text.bytes().all(|b| b.is_ascii_digit())
}

pub struct Term {
    pub sort: Sort,
    pub variables: BTreeSet<String>,
    pub atoms: BTreeSet<(u8, String)>,
}

type Value<'a> = (Sort, Option<&'a str>);

fn variable(token: &str, query: bool) -> Result<Sort> {
    let (name, sort) = token
        .split_once(':')
        .ok_or(Rejected("native variable: unsupported sort or index"))?;
    let sort = Sort::named(sort)
        .filter(|s| *s != Sort::Top)
        .ok_or(Rejected("native variable: unsupported sort or index"))?;
    if !decimal(&name[1..]) {
        return Err(Rejected("native variable: unsupported sort or index"));
    }
    if query && !name.starts_with('x') {
        return Err(Rejected(
            "native query: unexpected fresh-variable namespace",
        ));
    }
    Ok(sort)
}

pub fn tokens(text: &str) -> Result<Vec<&str>> {
    let bytes = text.as_bytes();
    let mut result = Vec::new();
    let mut position = 0;
    while position < bytes.len() {
        if space(bytes[position]) {
            position += 1;
            continue;
        }
        let start = position;
        let mut end = position + 1;
        if matches!(bytes[start], b'x' | b'#' | b'%') {
            while end < bytes.len() && bytes[end].is_ascii_digit() {
                end += 1;
            }
            if end > start + 1
                && bytes.get(end) == Some(&b':')
                && bytes.get(end + 1).is_some_and(u8::is_ascii_alphabetic)
            {
                end += 2;
                while end < bytes.len() && bytes[end].is_ascii_alphanumeric() {
                    end += 1;
                }
                result.push(&text[start..end]);
                position = end;
                continue;
            }
        }
        end = start + 1;
        if bytes[start].is_ascii_alphabetic() {
            while end < bytes.len() && bytes[end].is_ascii_alphanumeric() {
                end += 1;
            }
        } else if bytes[start].is_ascii_digit() {
            while end < bytes.len() && bytes[end].is_ascii_digit() {
                end += 1;
            }
        } else if !matches!(bytes[start], b'(' | b')' | b',') {
            return Err(Rejected("native term: unsupported token"));
        }
        result.push(&text[start..end]);
        position = end;
    }
    Ok(result)
}

fn application<'a>(
    name: &str,
    arguments: &[Value<'a>],
    atoms: &mut BTreeSet<(u8, String)>,
) -> Result<Value<'a>> {
    let atom_sort = match name {
        "p" => Some(Sort::Pub),
        "f" => Some(Sort::Fresh),
        "c" => Some(Sort::Msg),
        "t" => Some(Sort::Natural),
        "n" => Some(Sort::Node),
        _ => None,
    };
    let sort = if let Some(sort) = atom_sort {
        if arguments.len() != 1 || arguments[0].0 != Sort::Decimal {
            return Err(Rejected("native atom: index is not a closed decimal"));
        }
        let index = arguments[0]
            .1
            .ok_or(Rejected("native atom: missing index"))?;
        atoms.insert((name.as_bytes()[0], index.to_owned()));
        sort
    } else if name == "nil" && arguments.is_empty() {
        Sort::Top
    } else if name == "list" && arguments.len() == 1 || name == "cons" && arguments.len() == 2 {
        if arguments.iter().any(|value| value.0 == Sort::Decimal) {
            return Err(Rejected("native framing: invalid child sort"));
        }
        if arguments.iter().any(|value| value.0.kind()) {
            Sort::KindFraming
        } else {
            Sort::Top
        }
    } else if name == "tamXCtone" && arguments.is_empty() {
        Sort::Natural
    } else if name == "tamtplus" && arguments.len() >= 2 {
        if arguments
            .iter()
            .any(|value| !matches!(value.0, Sort::Natural | Sort::Fresh | Sort::KindNatural))
        {
            return Err(Rejected("native natural sum: non-natural operand"));
        }
        if arguments.iter().all(|value| value.0 == Sort::Natural) {
            Sort::Natural
        } else {
            Sort::KindNatural
        }
    } else if let Some((_, arity)) = name
        .strip_prefix("tamXC")
        .and_then(|name| FUNCTIONS.iter().find(|entry| entry.0 == name))
    {
        if arguments.len() != *arity {
            return Err(Rejected("native message function: wrong arity"));
        }
        if arguments.iter().any(|value| !value.0.message()) {
            return Err(Rejected("native message function: invalid operand sort"));
        }
        if arguments.iter().any(|value| value.0.kind()) {
            Sort::KindMessage
        } else {
            Sort::Msg
        }
    } else {
        return Err(Rejected("native term: unreviewed constructor or arity"));
    };
    Ok((sort, None))
}

pub fn term(text: &str, query: bool) -> Result<Term> {
    if !text.is_ascii() {
        return Err(Rejected("native term: non-ASCII syntax"));
    }
    let tokens = tokens(trim(text))?;
    let mut position = 0;
    let mut frames: Vec<(&str, Vec<Value<'_>>)> = Vec::new();
    let mut variables = BTreeSet::new();
    let mut atoms = BTreeSet::new();
    let mut expecting = true;
    let mut result = (Sort::Decimal, None);
    loop {
        if expecting {
            let token = tokens
                .get(position)
                .ok_or(Rejected("native term: truncated argument"))?;
            position += 1;
            result = if token.contains(':') {
                let sort = variable(token, query)?;
                variables.insert((*token).to_owned());
                (sort, None)
            } else if decimal(token) {
                (Sort::Decimal, Some(*token))
            } else if token.as_bytes()[0].is_ascii_alphabetic() {
                if tokens.get(position) == Some(&"(") {
                    position += 1;
                    frames.push((token, Vec::new()));
                    continue;
                }
                application(token, &[], &mut atoms)?
            } else {
                return Err(Rejected("native term: expected constructor"));
            };
            expecting = false;
        }
        let Some((_, arguments)) = frames.last_mut() else {
            if position != tokens.len() || result.0 == Sort::Decimal {
                return Err(Rejected(
                    "native term: trailing syntax or unsupported root sort",
                ));
            }
            return Ok(Term {
                sort: result.0,
                variables,
                atoms,
            });
        };
        arguments.push(result);
        let delimiter = tokens
            .get(position)
            .ok_or(Rejected("native term: unclosed application"))?;
        position += 1;
        if *delimiter == "," {
            expecting = true;
            continue;
        }
        if *delimiter != ")" {
            return Err(Rejected("native term: malformed argument separator"));
        }
        let (name, arguments) = frames
            .pop()
            .ok_or(Rejected("native term: missing result"))?;
        result = application(name, &arguments, &mut atoms)?;
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    use super::{Sort, term};

    // Generated by QueryModuleExport.lean; termination.py rejects a stale copy.
    const CORPUS: &str = include_str!("../tests/syntax_corpus.txt");

    fn expected(sort: &str) -> Option<Sort> {
        match sort {
            "KindNatural" => Some(Sort::KindNatural),
            "KindMessage" => Some(Sort::KindMessage),
            "KindFraming" => Some(Sort::KindFraming),
            _ => Sort::named(sort),
        }
    }

    fn entries(field: &str) -> BTreeSet<String> {
        if field == "-" {
            BTreeSet::new()
        } else {
            field.split(' ').map(str::to_owned).collect()
        }
    }

    #[test]
    fn recognizer_agrees_with_the_lean_syntax_corpus() {
        let (mut accepted, mut rejected) = (0, 0);
        for line in CORPUS.lines() {
            match line.split('\t').collect::<Vec<_>>().as_slice() {
                ["ACCEPT", sort, text, variables, atoms] => {
                    let Ok(parsed) = term(text, true) else {
                        panic!("recognizer rejected Lean rendering {text}");
                    };
                    assert_eq!(Some(parsed.sort), expected(sort), "{text}");
                    assert_eq!(parsed.variables, entries(variables), "{text}");
                    let found: BTreeSet<String> = parsed
                        .atoms
                        .iter()
                        .map(|(kind, index)| format!("{}:{index}", char::from(*kind)))
                        .collect();
                    assert_eq!(found, entries(atoms), "{text}");
                    accepted += 1;
                }
                ["REJECT", text] => {
                    assert!(term(text, true).is_err(), "recognizer accepted {text}");
                    rejected += 1;
                }
                ["EQUAL" | "DISTINCT", _, _] => {}
                _ => panic!("malformed corpus line {line}"),
            }
        }
        assert!(accepted > 0 && rejected > 0);
    }
}
