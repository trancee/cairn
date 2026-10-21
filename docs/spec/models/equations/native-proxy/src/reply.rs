use std::collections::BTreeMap;

use crate::{
    certificate,
    error::{Error::Rejected, Result},
    query::{Kind, Query},
    syntax::{Sort, lines, term},
    unifier,
};

const INCOMPLETE: &str = "native reply: solution family is incomplete";

fn value(
    query: &Query,
    text: &str,
    expected: Sort,
    upper: Option<Sort>,
    binding: bool,
    fresh: &mut BTreeMap<String, u8>,
) -> Result<()> {
    let result = term(text, false)?;
    if !result.sort.below(expected) || upper.is_some_and(|sort| !result.sort.below(sort)) {
        return Err(Rejected(if binding {
            "native binding: incompatible sort"
        } else {
            "native reply: incompatible result sort"
        }));
    }
    for atom in result.atoms {
        if !query.terms.iter().any(|term| term.atoms.contains(&atom)) {
            return Err(Rejected("native reply: new rigid atom index"));
        }
    }
    for variable in result.variables {
        let prefix = variable.as_bytes()[0];
        if prefix == b'x'
            && !query
                .terms
                .iter()
                .any(|term| term.variables.contains(&variable))
        {
            return Err(Rejected("native reply: unbound original variable"));
        }
        if (prefix == b'x') != matches!(query.kind, Kind::Reduce | Kind::Match) {
            return Err(Rejected("native reply: incompatible variable namespace"));
        }
        if prefix != b'x' && *fresh.entry(variable[1..].to_owned()).or_insert(prefix) != prefix {
            return Err(Rejected(
                "native reply: ambiguous generated variable namespace",
            ));
        }
    }
    Ok(())
}

fn sorted_value(text: &str) -> Option<(Sort, &str)> {
    let (sort, text) = text.split_once(": ")?;
    Some((Sort::named(sort)?, text)).filter(|(_, text)| !text.is_empty())
}

fn rewrites(line: &str) -> bool {
    line.strip_prefix("rewrites: ")
        .is_some_and(|count| !count.is_empty() && count.bytes().all(|byte| byte.is_ascii_digit()))
}

pub fn validate(query: &Query, reply: &str) -> Result<()> {
    if !reply.is_ascii() {
        return Err(Rejected("native reply: non-ASCII syntax"));
    }
    let mut lines: Vec<_> = lines(reply).collect();
    let upper = query
        .terms
        .first()
        .ok_or(Rejected("native query: missing term"))?
        .sort;
    if query.kind == Kind::Reduce {
        let (sort, text) = lines
            .first()
            .and_then(|line| line.strip_prefix("result "))
            .and_then(sorted_value)
            .ok_or(Rejected("native reply: malformed reduction result"))?;
        if lines.len() != 1 {
            return Err(Rejected("native reply: malformed reduction result"));
        }
        return value(query, text, sort, Some(upper), false, &mut BTreeMap::new());
    }
    let principal = unifier::principal(query)?;
    if query.kind == Kind::Unify && lines == ["No unifier."]
        || query.kind == Kind::Match && lines == ["No match."]
    {
        return if principal.is_some() {
            Err(Rejected(INCOMPLETE))
        } else {
            Ok(())
        };
    }
    if query.kind == Kind::Variants {
        if lines.len() < 2
            || lines[lines.len() - 2] != "No more variants."
            || !rewrites(lines[lines.len() - 1])
        {
            return Err(Rejected("native reply: missing variant exhaustion"));
        }
        lines.truncate(lines.len() - 2);
    }
    let header = match query.kind {
        Kind::Unify => "Unifier",
        Kind::Match => "Matcher",
        Kind::Variants => "Variant",
        Kind::Reduce => return Err(Rejected("native reply: malformed reduction result")),
    };
    let mut position = 0;
    let mut count = 0usize;
    let mut family = Vec::new();
    while position < lines.len() {
        let mut fresh = BTreeMap::new();
        count = count
            .checked_add(1)
            .ok_or(Rejected("native reply: solution counter overflow"))?;
        if lines[position] != format!("{header} {count}")
            && lines[position] != format!("{header} #{count}")
        {
            return Err(Rejected(
                "native reply: missing or malformed solution header",
            ));
        }
        position += 1;
        if query.kind == Kind::Variants {
            if !lines.get(position).is_some_and(|line| rewrites(line)) {
                return Err(Rejected("native reply: missing variant metadata"));
            }
            position += 1;
            let (sort, text) = lines
                .get(position)
                .and_then(|line| sorted_value(line))
                .ok_or(Rejected("native reply: missing variant term"))?;
            value(query, text, sort, Some(upper), false, &mut fresh)?;
            position += 1;
        }
        let mut bindings = BTreeMap::new();
        if lines.get(position) == Some(&"empty substitution") {
            if query.kind == Kind::Variants {
                return Err(Rejected(
                    "native reply: unsupported variant substitution marker",
                ));
            }
            position += 1;
        } else {
            while let Some(line) = lines.get(position).filter(|line| line.contains(" --> ")) {
                let (variable, text) = line
                    .split_once(" --> ")
                    .filter(|(variable, text)| {
                        !text.is_empty()
                            && query
                                .terms
                                .iter()
                                .any(|term| term.variables.contains(*variable))
                    })
                    .ok_or(Rejected("native reply: unknown or duplicate binding"))?;
                if bindings.insert(variable, text).is_some() {
                    return Err(Rejected("native reply: unknown or duplicate binding"));
                }
                let sort = variable
                    .split_once(':')
                    .and_then(|(_, sort)| Sort::named(sort))
                    .ok_or(Rejected("native reply: unknown or duplicate binding"))?;
                value(query, text, sort, None, true, &mut fresh)?;
                position += 1;
            }
            if bindings.is_empty() && query.kind != Kind::Variants {
                return Err(Rejected("native reply: missing substitution"));
            }
        }
        if matches!(query.kind, Kind::Unify | Kind::Match) {
            certificate::check(query, &bindings)?;
            family.push(bindings);
        }
    }
    if count == 0 {
        return Err(Rejected("native reply: missing solutions"));
    }
    if query.kind == Kind::Unify
        && let Some(principal) = principal
        && !principal.covered(&family)?
    {
        return Err(Rejected(INCOMPLETE));
    }
    Ok(())
}
