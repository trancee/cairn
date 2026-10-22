use std::collections::BTreeSet;

use crate::{
    certificate,
    error::Result,
    reduction::normalize,
    unifier::{FUEL, Outcome, SIZE_LIMIT, Tree, lookup, matcher, render, substitute, unify},
};

// Beyond Lean, more schemes than this make no claim.
const SCHEME_LIMIT: usize = 4_096;

pub type Equations = Vec<(Tree, Tree)>;

pub struct Scheme {
    pub value: Tree,
    pub equations: Equations,
    next: usize,
}

fn fresh(index: usize) -> Tree {
    Tree::Variable(format!("x{index}:Msg"))
}

fn apply(name: &str, children: Vec<Tree>) -> Tree {
    Tree::Apply(name.to_owned(), children)
}

// `nativeFreshBase`: one above every canonical `x<index>:<Sort>` query variable index.
fn fresh_base(tree: &Tree, base: &mut usize) -> Option<()> {
    match tree {
        Tree::Variable(name) => {
            let digits = name.strip_prefix('x')?.split_once(':')?.0;
            if digits.is_empty()
                || !digits.bytes().all(|byte| byte.is_ascii_digit())
                || digits.len() > 1 && digits.starts_with('0')
            {
                return None;
            }
            *base = (*base).max(digits.parse::<usize>().ok()?.checked_add(1)?);
            Some(())
        }
        Tree::Apply(_, children) => children
            .iter()
            .try_for_each(|child| fresh_base(child, base)),
    }
}

// `nativeUnaryVariantSchemes` and `nativeBinaryVariantSchemes`: the term stays, or one guarded
// rule fires with fresh message pattern variables and its equations in front.
fn root(name: &str, values: Vec<Tree>, equations: Equations, next: usize, out: &mut Vec<Scheme>) {
    let stay = apply(name, values.clone());
    let rule = |value: Tree, front: Equations, next: usize| {
        let mut all = front;
        all.extend(equations.iter().cloned());
        Scheme {
            value,
            equations: all,
            next,
        }
    };
    let rules: Vec<Scheme> = match (name, values.as_slice()) {
        ("tamXCfst" | "tamXCsnd", [value]) => {
            let pair = apply("tamXCpair", vec![fresh(next), fresh(next + 1)]);
            let picked = if name == "tamXCfst" { next } else { next + 1 };
            vec![rule(fresh(picked), vec![(value.clone(), pair)], next + 2)]
        }
        ("tamXCflip", [value]) => vec![
            rule(
                apply("tamXCroleB", vec![]),
                vec![(value.clone(), apply("tamXCroleA", vec![]))],
                next,
            ),
            rule(
                apply("tamXCroleA", vec![]),
                vec![(value.clone(), apply("tamXCroleB", vec![]))],
                next,
            ),
        ],
        ("tamXCsdec" | "tamXCkdec", [left, right]) => {
            let cipher = if name == "tamXCsdec" {
                apply("tamXCsenc", vec![fresh(next), fresh(next + 1)])
            } else {
                apply(
                    "tamXCkem",
                    vec![fresh(next), apply("tamXCpk", vec![fresh(next + 1)])],
                )
            };
            vec![rule(
                fresh(next),
                vec![(left.clone(), cipher), (right.clone(), fresh(next + 1))],
                next + 2,
            )]
        }
        _ => vec![],
    };
    out.push(Scheme {
        value: stay,
        equations,
        next,
    });
    out.extend(rules);
}

// `nativeVariantSchemes`: children left to right as in `nativeJoinVariantSchemes`, then the root.
fn schemes_from(tree: &Tree, next: usize) -> Option<Vec<Scheme>> {
    let Tree::Apply(name, children) = tree else {
        return Some(vec![Scheme {
            value: tree.clone(),
            equations: vec![],
            next,
        }]);
    };
    let mut partial = vec![(Vec::new(), Vec::new(), next)];
    for child in children {
        let mut extended = Vec::new();
        for (values, equations, after) in partial {
            for scheme in schemes_from(child, after)? {
                let mut values: Vec<Tree> = values.clone();
                values.push(scheme.value);
                let mut equations: Equations = equations.clone();
                equations.extend(scheme.equations);
                extended.push((values, equations, scheme.next));
                if extended.len() > SCHEME_LIMIT {
                    return None;
                }
            }
        }
        partial = extended;
    }
    let mut out = Vec::new();
    for (values, equations, after) in partial {
        root(name, values, equations, after, &mut out);
    }
    (out.len() <= SCHEME_LIMIT).then_some(out)
}

pub fn schemes(term: &Tree) -> Option<Vec<Scheme>> {
    let mut base = 0;
    fresh_base(term, &mut base)?;
    schemes_from(term, base)
}

// `nativeVariantSystem`.
pub fn system(term: &Tree, scheme: &Scheme) -> Equations {
    let mut equations = scheme.equations.clone();
    equations.push((term.clone(), term.clone()));
    equations.push((scheme.value.clone(), scheme.value.clone()));
    equations
}

fn variables(tree: &Tree, found: &mut BTreeSet<String>) {
    match tree {
        Tree::Variable(name) => {
            found.insert(name.clone());
        }
        Tree::Apply(_, children) => children.iter().for_each(|child| variables(child, found)),
    }
}

pub struct Member {
    pub value: Tree,
    pub bindings: Vec<(String, Tree)>,
}

// `native_variant_member_sound`: the value must be AC-equal to the normal form of its instance.
pub fn sound(term: &Tree, member: &Member, value: &str) -> Result<Option<bool>> {
    let Some(instance) = substitute(term, &member.bindings, &mut SIZE_LIMIT.clone()) else {
        return Ok(None);
    };
    Ok(Some(certificate::equivalent(
        &render(&normalize(&instance)?),
        value,
    )?))
}

// `native_variant_family_complete`: with every scheme decided, each solved scheme whose general
// value instance is normal must have its most general unifier and that value generalized by some
// member; `None` makes no claim.
pub fn complete(term: &Tree, family: &[Member]) -> Result<Option<bool>> {
    let Some(schemes) = schemes(term) else {
        return Ok(None);
    };
    let mut solved = Vec::new();
    for scheme in &schemes {
        match unify(FUEL, system(term, scheme))? {
            Outcome::Solved(bindings) => solved.push((scheme, bindings)),
            Outcome::Failed => {}
            Outcome::Unsupported => return Ok(None),
        }
    }
    let mut keys = BTreeSet::new();
    variables(term, &mut keys);
    for (scheme, general) in solved {
        let Some(target) = substitute(&scheme.value, &general, &mut SIZE_LIMIT.clone()) else {
            return Ok(None);
        };
        let target_text = render(&target);
        if !certificate::equivalent(&target_text, &render(&normalize(&target)?))? {
            continue;
        }
        let mut covered = false;
        for member in family {
            let mut pairs: Equations = keys
                .iter()
                .map(|key| {
                    let variable = Tree::Variable(key.clone());
                    let pattern = lookup(key, &member.bindings)
                        .cloned()
                        .unwrap_or(variable.clone());
                    (pattern, lookup(key, &general).cloned().unwrap_or(variable))
                })
                .collect();
            pairs.push((member.value.clone(), target.clone()));
            if !matches!(matcher(FUEL, pairs)?, Outcome::Failed) {
                covered = true;
                break;
            }
        }
        if !covered {
            return Ok(Some(false));
        }
    }
    Ok(Some(true))
}

#[cfg(test)]
mod tests {
    use super::{schemes, system};
    use crate::unifier::{FUEL, Outcome, parse, render, unify};

    // Generated by QueryModuleExport.lean from `nativeVariantSchemeResults`.
    const CORPUS: &str = include_str!("../tests/syntax_corpus.txt");

    fn outcome(outcome: Outcome) -> String {
        match outcome {
            Outcome::Solved(bindings) if bindings.is_empty() => "SOLVED\t-".to_owned(),
            Outcome::Solved(bindings) => {
                let bindings: Vec<_> = bindings
                    .iter()
                    .map(|(key, value)| format!("{key} --> {}", render(value)))
                    .collect();
                format!("SOLVED\t{}", bindings.join(" ; "))
            }
            Outcome::Failed => "FAILED\t-".to_owned(),
            Outcome::Unsupported => "UNSUPPORTED\t-".to_owned(),
        }
    }

    #[test]
    fn schemes_agree_with_the_lean_variant_corpus() {
        let mut expected: Vec<(String, Vec<String>)> = Vec::new();
        for line in CORPUS.lines() {
            let Some(rest) = line.strip_prefix("VARIANT\t") else {
                continue;
            };
            let Some((term, scheme)) = rest.split_once('\t') else {
                panic!("malformed corpus line {line}");
            };
            match expected.last_mut() {
                Some((last, lines)) if last == term => lines.push(scheme.to_owned()),
                _ => expected.push((term.to_owned(), vec![scheme.to_owned()])),
            }
        }
        let mut statuses = std::collections::BTreeSet::new();
        for (text, lines) in &expected {
            let Some(term) = parse(text) else {
                panic!("parser rejected Lean rendering {text}");
            };
            let Some(found) = schemes(&term) else {
                panic!("no schemes for {text}");
            };
            let found: Vec<String> = found
                .iter()
                .map(|scheme| {
                    let equations = system(&term, scheme);
                    let problem: Vec<_> = equations
                        .iter()
                        .map(|(left, right)| format!("{} =? {}", render(left), render(right)))
                        .collect();
                    let Ok(result) = unify(FUEL, equations) else {
                        panic!("unifier could not compare {text}");
                    };
                    let result = outcome(result);
                    statuses.insert(result.split('\t').next().unwrap_or_default().to_owned());
                    format!(
                        "{}\t{}\t{result}",
                        render(&scheme.value),
                        problem.join(" /\\ ")
                    )
                })
                .collect();
            assert_eq!(&found, lines, "{text}");
        }
        assert!(expected.len() > 20 && statuses.len() == 3);
    }
}
