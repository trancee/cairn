use std::collections::{BTreeMap, BTreeSet};

use crate::{
    certificate,
    error::Result,
    query::{Kind, Query},
    syntax::tokens,
};

// Mirrors `nativeSyntacticUnify` and `nativeSyntacticMatch` (QuerySyntacticUnification.lean) over
// Maude renderings: atoms such as `p(0)` are single leaves and n-ary sums are read right-nested.
// Beyond Lean, terms above `SIZE_LIMIT` nodes and composed bindings above it are `Unsupported`;
// `Unsupported` makes no claim, so this only narrows what the guard enforces.
pub const FUEL: usize = 65_536;
pub const SIZE_LIMIT: usize = 4_096;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Tree {
    Variable(String),
    Apply(String, Vec<Tree>),
}

pub enum Outcome {
    Solved(Vec<(String, Tree)>),
    Failed,
    Unsupported,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Sort {
    Pub,
    Fresh,
    Msg,
    Natural,
    Node,
}

fn variable_sort(name: &str) -> Option<Sort> {
    match name.split_once(':')?.1 {
        "Pub" => Some(Sort::Pub),
        "Fresh" => Some(Sort::Fresh),
        "Msg" => Some(Sort::Msg),
        "TamNat" => Some(Sort::Natural),
        "Node" => Some(Sort::Node),
        _ => None,
    }
}

fn atom(name: &str) -> Option<u8> {
    name.ends_with(')').then(|| name.as_bytes()[0])
}

fn close(name: &str, mut children: Vec<Tree>) -> Option<Tree> {
    if matches!(name, "p" | "f" | "c" | "t" | "n") {
        return match children.as_slice() {
            [Tree::Apply(index, inner)]
                if inner.is_empty() && index.bytes().all(|byte| byte.is_ascii_digit()) =>
            {
                Some(Tree::Apply(format!("{name}({index})"), Vec::new()))
            }
            _ => None,
        };
    }
    if name == "tamtplus" {
        let mut sum = children.pop()?;
        if children.is_empty() {
            return None;
        }
        while let Some(summand) = children.pop() {
            sum = Tree::Apply(name.to_owned(), vec![summand, sum]);
        }
        return Some(sum);
    }
    Some(Tree::Apply(name.to_owned(), children))
}

// Iterative so reply nesting cannot exhaust the stack; `None` above `SIZE_LIMIT` nodes.
pub fn parse(text: &str) -> Option<Tree> {
    let tokens = tokens(text.trim()).ok()?;
    let mut frames: Vec<(&str, Vec<Tree>)> = Vec::new();
    let mut position = 0;
    let mut nodes = 0usize;
    loop {
        let token = *tokens.get(position)?;
        position += 1;
        if matches!(token, "(" | ")" | ",") {
            return None;
        }
        if tokens.get(position) == Some(&"(") {
            position += 1;
            frames.push((token, Vec::new()));
            continue;
        }
        nodes += 1;
        let mut value = if token.contains(':') {
            Tree::Variable(token.to_owned())
        } else {
            Tree::Apply(token.to_owned(), Vec::new())
        };
        loop {
            let Some(frame) = frames.last_mut() else {
                return (position == tokens.len() && size(&value) <= SIZE_LIMIT).then_some(value);
            };
            frame.1.push(value);
            match tokens.get(position) {
                Some(&",") => {
                    position += 1;
                    break;
                }
                Some(&")") => {
                    position += 1;
                    let (name, children) = frames.pop()?;
                    nodes += 1;
                    if nodes > 2 * SIZE_LIMIT {
                        return None;
                    }
                    value = close(name, children)?;
                }
                _ => return None,
            }
        }
    }
}

fn size(tree: &Tree) -> usize {
    match tree {
        Tree::Variable(_) => 1,
        Tree::Apply(_, children) => 1 + children.iter().map(size).sum::<usize>(),
    }
}

fn head(tree: &Tree) -> &str {
    match tree {
        Tree::Variable(name) | Tree::Apply(name, _) => name,
    }
}

fn children(tree: &Tree) -> &[Tree] {
    match tree {
        Tree::Variable(_) => &[],
        Tree::Apply(_, children) => children,
    }
}

fn occurs_any(tree: &Tree) -> bool {
    match tree {
        Tree::Variable(_) => true,
        Tree::Apply(_, children) => children.iter().any(occurs_any),
    }
}

fn occurs(key: &str, tree: &Tree) -> bool {
    match tree {
        Tree::Variable(name) => name == key,
        Tree::Apply(_, children) => children.iter().any(|child| occurs(key, child)),
    }
}

// `decodeNativeNatural`, `decodeNativeMessage` and `nativeSortedValueCheck`.
fn natural(tree: &Tree) -> bool {
    match tree {
        Tree::Variable(name) => variable_sort(name) == Some(Sort::Natural),
        Tree::Apply(name, children) => match name.as_str() {
            "tamXCtone" => true,
            "tamtplus" => children.iter().all(natural),
            _ => atom(name) == Some(b't'),
        },
    }
}

pub fn message(tree: &Tree) -> bool {
    match tree {
        Tree::Variable(name) => variable_sort(name).is_some_and(|sort| sort != Sort::Node),
        Tree::Apply(name, children) => match name.as_str() {
            "tamtplus" => natural(tree),
            "list" | "cons" | "nil" => false,
            _ => match atom(name) {
                Some(kind) => kind != b'n',
                None => children.iter().all(message),
            },
        },
    }
}

fn sorted(sort: Sort, tree: &Tree) -> bool {
    let (letter, sort_name) = match sort {
        Sort::Msg => return message(tree),
        Sort::Natural => return natural(tree),
        Sort::Pub => (b'p', Sort::Pub),
        Sort::Fresh => (b'f', Sort::Fresh),
        Sort::Node => (b'n', Sort::Node),
    };
    match tree {
        Tree::Variable(name) => variable_sort(name) == Some(sort_name),
        Tree::Apply(name, _) => atom(name) == Some(letter),
    }
}

fn intersects(first: Sort, second: Sort) -> bool {
    first == second
        || matches!(
            (first, second),
            (Sort::Pub | Sort::Fresh | Sort::Natural, Sort::Msg)
                | (Sort::Msg, Sort::Pub | Sort::Fresh | Sort::Natural)
        )
}

// `nativeSortRequirements expected tree` is `some`.
fn refinable(expected: Sort, tree: &Tree) -> bool {
    match tree {
        Tree::Variable(name) => variable_sort(name).is_some_and(|sort| intersects(sort, expected)),
        Tree::Apply(name, children) => match name.as_str() {
            "tamtplus" => {
                matches!(expected, Sort::Natural | Sort::Msg)
                    && children.iter().all(|child| refinable(Sort::Natural, child))
            }
            "list" | "cons" | "nil" => false,
            _ if children.is_empty() => sorted(expected, tree),
            _ => expected == Sort::Msg && children.iter().all(|child| refinable(Sort::Msg, child)),
        },
    }
}

// `nativeSortRefuted`: `natural` is `nativeAlwaysNatural`, since its requirements restate only
// natural variables' own sort.
fn sort_refuted(left: &Tree, right: &Tree) -> bool {
    !refinable(Sort::Natural, left) && natural(right)
        || !refinable(Sort::Natural, right) && natural(left)
}

pub fn lookup<'a>(key: &str, bindings: &'a [(String, Tree)]) -> Option<&'a Tree> {
    bindings
        .iter()
        .find_map(|(bound, value)| (bound == key).then_some(value))
}

// Substitutes within a node budget; `None` once the result would exceed it.
pub fn substitute(tree: &Tree, bindings: &[(String, Tree)], budget: &mut usize) -> Option<Tree> {
    match tree {
        Tree::Variable(name) => {
            let value = lookup(name, bindings).unwrap_or(tree);
            *budget = budget.checked_sub(size(value))?;
            Some(value.clone())
        }
        Tree::Apply(name, children) => {
            *budget = budget.checked_sub(1)?;
            let children = children
                .iter()
                .map(|child| substitute(child, bindings, budget))
                .collect::<Option<_>>()?;
            Some(Tree::Apply(name.clone(), children))
        }
    }
}

fn push_children(stack: &mut Vec<(Tree, Tree)>, left: &Tree, right: &Tree) {
    for pair in children(left)
        .iter()
        .cloned()
        .zip(children(right).iter().cloned())
        .rev()
    {
        stack.push(pair);
    }
}

fn summands(tree: &Tree) -> Vec<Tree> {
    let mut found = Vec::new();
    let mut pending = vec![tree];
    while let Some(node) = pending.pop() {
        match node {
            Tree::Apply(name, children) if name == "tamtplus" => {
                pending.extend(children.iter().rev());
            }
            _ => found.push(node.clone()),
        }
    }
    found
}

// `nativeACRebuild` on a nonempty list.
fn rebuild(mut terms: Vec<Tree>) -> Option<Tree> {
    let mut sum = terms.pop()?;
    while let Some(summand) = terms.pop() {
        sum = Tree::Apply("tamtplus".to_owned(), vec![summand, sum]);
    }
    Some(sum)
}

enum Sum {
    Solved,
    Failed,
    Equation(Tree, Tree),
    Unsupported,
}

// `nativeSumCancel`, then the remainder cases shared by unification and matching; matching
// (`reversible` false) has no case for a single remaining subject summand.
fn cancel_sums(
    left: &Tree,
    right: &Tree,
    reversible: bool,
    cancels: impl Fn(&Tree, &Tree) -> Result<bool>,
) -> Result<Sum> {
    let mut others = summands(right);
    let mut kept = Vec::new();
    for term in summands(left) {
        let mut partner = None;
        for (position, other) in others.iter().enumerate() {
            if cancels(&term, other)? {
                partner = Some(position);
                break;
            }
        }
        match partner {
            Some(position) => {
                others.remove(position);
            }
            None => kept.push(term),
        }
    }
    Ok(match (kept.len(), others.len()) {
        (0, 0) => Sum::Solved,
        (0, _) | (_, 0) => Sum::Failed,
        (1, _) => match (kept.pop(), rebuild(others)) {
            (Some(kept), Some(others)) => Sum::Equation(kept, others),
            _ => Sum::Unsupported,
        },
        (_, 1) if reversible => match (rebuild(kept), others.pop()) {
            (Some(kept), Some(other)) => Sum::Equation(kept, other),
            _ => Sum::Unsupported,
        },
        _ => Sum::Unsupported,
    })
}

// The stack's last entry is the head of Lean's equation list.
pub fn unify(mut fuel: usize, equations: Vec<(Tree, Tree)>) -> Result<Outcome> {
    let mut stack: Vec<_> = equations.into_iter().rev().collect();
    let mut eliminated: Vec<(String, Tree)> = Vec::new();
    loop {
        if fuel == 0 {
            return Ok(Outcome::Unsupported);
        }
        let Some((left, right)) = stack.pop() else {
            break;
        };
        fuel -= 1;
        if left == right {
            continue;
        }
        let (key, value) = match (&left, &right) {
            (Tree::Variable(key), value) | (value, Tree::Variable(key)) => (key, value),
            _ => {
                if head(&left) != head(&right) {
                    return Ok(Outcome::Failed);
                }
                if head(&left) == "tamtplus" {
                    match cancel_sums(&left, &right, true, equivalent)? {
                        Sum::Solved => {}
                        Sum::Failed => return Ok(Outcome::Failed),
                        Sum::Equation(first, second) => stack.push((first, second)),
                        Sum::Unsupported if sort_refuted(&left, &right) => {
                            return Ok(Outcome::Failed);
                        }
                        Sum::Unsupported => return Ok(Outcome::Unsupported),
                    }
                    continue;
                }
                push_children(&mut stack, &left, &right);
                continue;
            }
        };
        let Some(sort) = variable_sort(key) else {
            return Ok(Outcome::Unsupported);
        };
        let binding = if occurs(key, value) {
            return Ok(Outcome::Failed);
        } else if sorted(sort, value) {
            (key.clone(), value.clone())
        } else if let Tree::Variable(other) = value
            && variable_sort(other).is_some_and(|other| sorted(other, &Tree::Variable(key.clone())))
        {
            (other.clone(), Tree::Variable(key.clone()))
        } else if refinable(sort, value) {
            return Ok(Outcome::Unsupported);
        } else {
            return Ok(Outcome::Failed);
        };
        let single = [binding];
        let mut budget = SIZE_LIMIT;
        let mut residual = Vec::with_capacity(stack.len());
        for (first, second) in &stack {
            let (Some(first), Some(second)) = (
                substitute(first, &single, &mut budget),
                substitute(second, &single, &mut budget),
            ) else {
                return Ok(Outcome::Unsupported);
            };
            residual.push((first, second));
        }
        stack = residual;
        let [binding] = single;
        eliminated.push(binding);
    }
    // `composeNativeBindings [(key, value)] later` for each elimination, innermost first.
    let mut composed: Vec<(String, Tree)> = Vec::new();
    while let Some((key, value)) = eliminated.pop() {
        let mut budget = SIZE_LIMIT;
        let Some(value) = substitute(&value, &composed, &mut budget) else {
            return Ok(Outcome::Unsupported);
        };
        composed.insert(0, (key, value));
    }
    Ok(Outcome::Solved(composed))
}

fn equivalent(left: &Tree, right: &Tree) -> Result<bool> {
    certificate::equivalent(&render(left), &render(right))
}

// Pattern variables are bindable; subject variables are constants.
pub fn matcher(mut fuel: usize, pairs: Vec<(Tree, Tree)>) -> Result<Outcome> {
    let mut stack: Vec<_> = pairs.into_iter().rev().collect();
    let mut bindings: Vec<(String, Tree)> = Vec::new();
    loop {
        if fuel == 0 {
            return Ok(Outcome::Unsupported);
        }
        let Some((pattern, subject)) = stack.pop() else {
            break;
        };
        fuel -= 1;
        if let Tree::Variable(key) = &pattern {
            if let Some(bound) = lookup(key, &bindings) {
                if !equivalent(bound, &subject)? {
                    return Ok(Outcome::Failed);
                }
            } else if variable_sort(key).is_some_and(|sort| sorted(sort, &subject)) {
                bindings.push((key.clone(), subject));
            } else {
                return Ok(Outcome::Failed);
            }
        } else if head(&pattern) != head(&subject) {
            return Ok(Outcome::Failed);
        } else if head(&pattern) == "tamtplus" {
            let ground =
                |term: &Tree, other: &Tree| Ok(!occurs_any(term) && equivalent(term, other)?);
            match cancel_sums(&pattern, &subject, false, ground)? {
                Sum::Solved => {}
                Sum::Failed => return Ok(Outcome::Failed),
                Sum::Equation(first, second) => stack.push((first, second)),
                Sum::Unsupported => return Ok(Outcome::Unsupported),
            }
        } else {
            push_children(&mut stack, &pattern, &subject);
        }
    }
    bindings.reverse();
    Ok(Outcome::Solved(bindings))
}

// A query's decisive Lean result: its most general unifier or a witness matcher.
pub struct Principal {
    variables: Vec<String>,
    bindings: Vec<(String, Tree)>,
}

pub fn principal(query: &Query) -> Result<Option<Principal>> {
    if !matches!(query.kind, Kind::Unify | Kind::Match) {
        return Ok(None);
    }
    let mut pairs = Vec::new();
    for [left, right] in query.sides.as_chunks::<2>().0 {
        let (Some(left), Some(right)) = (parse(left), parse(right)) else {
            return Ok(None);
        };
        pairs.push((left, right));
    }
    let outcome = if query.kind == Kind::Unify {
        unify(FUEL, pairs)?
    } else {
        matcher(FUEL, pairs)?
    };
    let Outcome::Solved(bindings) = outcome else {
        return Ok(None);
    };
    let variables: BTreeSet<_> = query
        .terms
        .iter()
        .flat_map(|term| term.variables.iter().cloned())
        .collect();
    Ok(Some(Principal {
        variables: variables.into_iter().collect(),
        bindings,
    }))
}

impl Principal {
    // `native_complete_family_cover_iff`: a sound family is complete iff some member
    // generalizes the most general unifier, decided by matching (`native_ac_instance_match_iff`).
    pub fn covered(&self, family: &[BTreeMap<&str, &str>]) -> Result<bool> {
        for solution in family {
            let mut pairs = Vec::new();
            for variable in &self.variables {
                let general = match solution.get(variable.as_str()) {
                    Some(text) => parse(text),
                    None => Some(Tree::Variable(variable.clone())),
                };
                let Some(general) = general else {
                    return Ok(true);
                };
                let specific = lookup(variable, &self.bindings)
                    .cloned()
                    .unwrap_or_else(|| Tree::Variable(variable.clone()));
                pairs.push((general, specific));
            }
            if !matches!(matcher(FUEL, pairs)?, Outcome::Failed) {
                return Ok(true);
            }
        }
        Ok(false)
    }
}

pub fn render(tree: &Tree) -> String {
    match tree {
        Tree::Variable(name) => name.clone(),
        Tree::Apply(name, children) if children.is_empty() => name.clone(),
        Tree::Apply(name, children) => {
            let children: Vec<_> = children.iter().map(render).collect();
            format!("{name}({})", children.join(","))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{FUEL, Outcome, matcher, parse, render, unify};

    // Generated by QueryModuleExport.lean from `nativeSyntacticUnify` and `nativeSyntacticMatch`.
    const CORPUS: &str = include_str!("../tests/syntax_corpus.txt");

    fn line(outcome: Outcome) -> String {
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

    fn pairs(problem: &str, relation: &str) -> Vec<(super::Tree, super::Tree)> {
        problem
            .split(" /\\ ")
            .map(|pair| {
                let Some((left, right)) = pair.split_once(relation) else {
                    panic!("malformed corpus problem {problem}");
                };
                let (Some(left), Some(right)) = (parse(left), parse(right)) else {
                    panic!("parser rejected Lean rendering {pair}");
                };
                (left, right)
            })
            .collect()
    }

    #[test]
    fn unifier_and_matcher_agree_with_the_lean_corpus() {
        let (mut unified, mut matched) = (0, 0);
        for entry in CORPUS.lines() {
            match entry.split('\t').collect::<Vec<_>>().as_slice() {
                ["UNIFY", problem, status, bindings] => {
                    let Ok(outcome) = unify(FUEL, pairs(problem, " =? ")) else {
                        panic!("unifier could not compare {problem}");
                    };
                    let found = line(outcome);
                    assert_eq!(found, format!("{status}\t{bindings}"), "{problem}");
                    unified += 1;
                }
                ["MATCH", problem, status, bindings] => {
                    let Ok(outcome) = matcher(FUEL, pairs(problem, " <=? ")) else {
                        panic!("matcher could not compare {problem}");
                    };
                    let found = line(outcome);
                    assert_eq!(found, format!("{status}\t{bindings}"), "{problem}");
                    matched += 1;
                }
                _ => {}
            }
        }
        assert!(unified > 300 && matched > 300);
    }
}
