"""Kernel-check typed convergence, boundedness and structural image correspondence."""

import argparse
import hashlib
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from equations import additive_audits, general_audits
from equations.maude_module import reviewed_module
from equations.signature import lean_correspondence, reviewed_signature
from equations.maude_runner import run_guarded_tamarin
from proof_tools import check_axioms, check_tamarin_version
from replay import ReplayError, run


AUDITED_THEOREMS = (
    "natural_ac_preserves_weight",
    "message_ac_preserves_weight",
    "primitive_rewrite_decreases_weight",
    "rewrite_decreases_weight",
    "modulo_ac_rewrite_decreases_weight",
    "modulo_ac_termination",
)
COHERENCE_THEOREMS = (
    "modulo_ac_matching_coherence",
    "matching_primitive_modulo_ac",
    "matching_rewrite_modulo_ac",
    "matching_termination",
    "matching_rewrite_ac_coherent",
)
BOUNDEDNESS_THEOREMS = (
    "matching_steps_transitive",
    "matching_steps_context",
    "normalized_substitution_bound",
)
CONFLUENCE_THEOREMS = (
    "matching_local_confluence",
    "matching_steps_do_not_increase_weight",
    "matching_confluence",
)
CONVERGENCE_THEOREMS = (
    "normal_ac_invariant",
    "matching_steps_ac_coherent",
    "matching_normal_forms_unique",
    "modulo_ac_steps_matching",
    "modulo_ac_confluence",
)
QUERY_IMAGE_THEOREMS = (
    "native_natural_round_trip",
    "native_message_round_trip",
    "native_natural_encoding_injective",
    "native_message_encoding_injective",
)
QUERY_RECOGNITION_THEOREMS = (
    "native_natural_recognition",
    "native_message_recognition",
)
QUERY_AC_THEOREMS = (
    "native_natural_ac_preservation",
    "native_message_ac_preservation",
    "native_natural_ac_reflection",
    "native_message_ac_reflection",
    "native_ac_natural_image",
    "native_ac_message_image",
)
QUERY_REWRITE_THEOREMS = (
    "native_primitive_preservation",
    "native_rewrite_preservation",
    "native_rewrite_decode",
    "native_rewrite_image",
    "native_rewrite_reflection",
    "native_modulo_ac_preservation",
    "native_modulo_ac_decode",
    "native_modulo_ac_reflection",
)
QUERY_MATCHING_THEOREMS = (
    "native_matching_preservation",
    "native_matching_realization",
)
QUERY_SUBSTITUTION_THEOREMS = (
    "native_natural_substitution",
    "native_message_substitution",
    "native_natural_substitution_image",
    "native_message_substitution_image",
    "native_ac_substitution",
    "native_rewrite_substitution",
)
QUERY_FRAMING_THEOREMS = (
    "native_framed_ac",
    "native_framed_rewrite",
    "native_framed_substitution",
)
QUERY_RELABELING_THEOREMS = (
    "native_ac_relabeling", "native_rewrite_relabeling", "native_modulo_ac_relabeling",
)
QUERY_KIND_THEOREMS = (
    "native_kind_round_trip", "native_kind_abstraction_injective",
    "native_kind_substitution", "native_kind_framed_substitution",
    "native_kind_ac_reflection", "native_kind_rewrite_reflection",
    "native_kind_modulo_ac_reflection", "native_kind_framed_ac", "native_kind_framed_rewrite",
    "native_kind_modulo_ac_decode", "native_kind_termination",
)
QUERY_SORTED_THEOREMS = (
    "native_sorted_matching_preservation", "native_sorted_rewrite_modulo_ac",
    "native_sorted_rewrite_decode", "native_sorted_kind_framed_rewrite",
    "native_sorted_proper_termination", "native_sorted_kind_termination",
)
QUERY_SORTED_CONVERGENCE_THEOREMS = (
    "native_sorted_ac_coherent", "native_sorted_steps_preservation", "native_sorted_steps_decode",
    "native_sorted_normal_iff", "native_sorted_normal_ac_invariant", "native_sorted_confluence",
    "native_sorted_normal_forms_unique", "native_sorted_normalized_substitution_bound",
)
QUERY_SORTED_BOUNDEDNESS_THEOREMS = (
    "native_sorted_steps_transitive", "native_sorted_steps_context",
    "native_sorted_query_substitution_bound",
)
QUERY_SORTED_EXACT_THEOREMS = (
    "native_sorted_primitive_image", "native_sorted_rewrite_matching_decode",
    "native_sorted_steps_matching_decode", "native_sorted_proper_confluence_exact",
)
QUERY_SORTED_GLOBAL_THEOREMS = (
    "native_sorted_rewrite_decreases_count", "native_sorted_termination",
    "native_sorted_local_confluence", "native_sorted_steps_count_bound",
    "native_sorted_matching_confluence",
)
QUERY_SORTED_AC_THEOREMS = (
    "native_query_ac_preserves_count", "native_sorted_query_ac_coherent",
)
QUERY_SORTED_QUOTIENT_THEOREMS = (
    "native_sorted_query_normal_ac_invariant", "native_sorted_query_steps_ac_coherent",
    "native_sorted_modulo_ac_termination", "native_sorted_modulo_ac_normal_iff",
    "native_sorted_modulo_ac_steps_matching", "native_sorted_modulo_ac_confluence",
    "native_sorted_modulo_ac_normal_forms_unique",
)
QUERY_SORTED_SUBSTITUTION_THEOREMS = (
    "native_typed_assignment_sorted", "native_sorted_assignment_representation",
    "native_sorted_proper_substitution", "native_sorted_rewrite_substitution",
    "native_sorted_steps_substitution", "native_sorted_modulo_ac_substitution",
    "native_sorted_modulo_ac_steps_substitution",
)
QUERY_KIND_SUBSTITUTION_THEOREMS = (
    "native_kind_natural_image", "native_kind_proper_image",
    "native_kind_assignment_sorted", "native_kind_shadow_representation",
    "native_kind_sorted_framed_substitution",
)
QUERY_COMPOSITION_THEOREMS = (
    "native_identity_assignment_sorted",
    "native_substitution_identity", "native_substitution_composition",
    "native_sorted_value_substitution", "native_sorted_composition",
    "native_composition_associative", "native_substitution_assignment_ac",
)
QUERY_UNIFICATION_THEOREMS = (
    "native_ac_unifier_composition", "native_message_ac_unifier_iff",
    "native_natural_ac_unifier_iff", "native_message_ac_unifier_representation",
    "native_natural_ac_unifier_representation",
    "native_kind_ac_unifier_iff", "native_kind_ac_unifier_representation",
)
QUERY_INSTANCE_THEOREMS = (
    "native_substitution_assignment_ac_on", "native_ac_instance_reflexive",
    "native_ac_instance_transitive", "native_ac_unifier_instance",
)
QUERY_TYPED_INSTANCE_THEOREMS = (
    "native_query_composition", "native_query_ac_leaf",
    "native_query_assignment_ac_on_iff", "native_query_ac_instance_iff",
)
QUERY_COMPLETENESS_THEOREMS = (
    "native_singleton_complete_iff", "query_singleton_complete_iff",
    "native_message_complete_unifiers_iff", "native_natural_complete_unifiers_iff",
    "native_message_most_general_iff", "native_natural_most_general_iff",
)
QUERY_SUPPORT_THEOREMS = (
    "native_substitution_eq_on", "native_restriction_supported",
    "native_restriction_sorted", "native_restriction_substitution",
    "native_bindings_restriction", "native_bindings_supported",
    "native_restriction_finite",
)
QUERY_FINITE_UNIFICATION_THEOREMS = (
    "native_ac_instance_finite_factor_iff", "native_ac_instance_restriction_iff",
    "native_ac_unifier_restriction_iff", "native_ac_unifier_finite_representation",
    "native_complete_unifiers_restriction_iff", "native_complete_unifiers_finite_solutions_iff",
    "native_most_general_finite_solutions_iff",
)
QUERY_KIND_INSTANCE_THEOREMS = (
    "native_kind_assignment_round_trip", "native_kind_assignment_injective",
    "native_kind_composition", "native_kind_admissible_iff",
    "native_kind_admissible_sorted", "native_kind_admissible_composition",
    "native_kind_assignment_lookup", "native_kind_query_variables",
    "native_kind_assignment_ac_on_iff",
    "native_kind_ac_instance_iff", "native_kind_admissible_unifier_iff",
)
QUERY_KIND_COMPLETENESS_THEOREMS = (
    "native_kind_singleton_complete_iff", "native_kind_complete_unifiers_iff",
    "native_kind_most_general_iff",
)
QUERY_OCCURS_THEOREMS = (
    "native_occurrence_substitution_count", "native_proper_occurrence_substitution_count",
    "native_ac_unifier_occurs_check", "native_occurs_complete_empty_family",
)
QUERY_VARIABLE_BINDING_THEOREMS = (
    "native_single_binding_sorted_iff", "native_single_binding_finite",
    "native_single_binding_supported", "native_single_binding_fixes_value",
    "native_single_binding_idempotent", "native_single_binding_unifier",
    "native_single_binding_factorization", "native_single_binding_most_general",
    "native_single_binding_complete_family", "native_single_binding_reversed_complete_family",
)
QUERY_VARIABLE_GENERATION_THEOREMS = (
    "native_reflexive_complete_family", "native_variable_binding_family_complete",
    "native_variable_binding_family_finite",
)
QUERY_SYSTEM_THEOREMS = (
    "native_system_cons_iff", "native_system_singleton_complete_iff",
    "native_system_substitution_iff", "native_system_assignment_ac",
    "native_system_assignment_eq_on",
    "native_system_empty_complete", "native_system_reflexive_complete_iff",
    "native_ac_instance_prefix", "native_system_swap_complete_iff",
)
QUERY_SORT_INTERSECTION_THEOREMS = (
    "native_sorted_value_check_iff", "native_sort_intersection_iff",
)
QUERY_SORT_SHAPE_THEOREMS = (
    "native_sorted_add_shape", "native_sorted_unary_shape",
    "native_sorted_binary_shape", "native_sorted_kdf_shape",
)
QUERY_SORT_REQUIREMENT_THEOREMS = (
    "native_sort_requirements_append_iff", "native_ground_sort_requirements_iff",
)
QUERY_SORT_REFINEMENT_THEOREMS = ("native_sort_requirements_iff",)
QUERY_PRINCIPAL_SORT_THEOREMS = ("native_principal_sort_iff",)
QUERY_SORT_FINGERPRINT_THEOREMS = ("native_sort_fingerprint_substitution",)
QUERY_SYSTEM_BINDING_THEOREMS = (
    "native_bindings_composition", "native_finite_assignment_composition",
    "native_system_variable_elimination", "native_system_reversed_variable_elimination",
    "native_system_single_binding_complete", "native_system_occurs_complete_empty_family",
)
QUERY_CONSTRUCTOR_THEOREMS = (
    "native_query_ac_head", "native_query_ac_free_children", "native_query_ac_constructor_iff",
    "native_ac_unary_iff", "native_ac_binary_iff", "native_ac_kdf_iff",
    "native_ac_list_iff", "native_ac_cons_iff",
)
QUERY_CONSTRUCTOR_SYSTEM_THEOREMS = (
    "native_system_unary_decomposition", "native_system_binary_decomposition",
    "native_system_kdf_decomposition", "native_system_list_decomposition",
    "native_system_cons_decomposition", "native_substitution_fixed_head",
    "native_system_constructor_clash",
    "native_constructor_decomposition_complete", "native_constructor_decomposition_decreases",
    "native_constructor_decomposition_termination",
)
NATURAL_MULTIPLICITY_THEOREMS = (
    "natural_atom_codes_nonempty", "natural_ac_atoms_iff",
    "natural_ac_multiplicity_iff", "natural_multiplicity_add",
    "natural_codes_decode_empty", "natural_codes_decode_exact", "natural_codes_decode_exists",
)
NATURAL_LINEARIZATION_THEOREMS = (
    "natural_linear_count_substitution", "natural_linear_unifier_iff",
)


def check_module_export(output: str, corpus: Path) -> None:
    module = reviewed_module()
    if not output.startswith(module):
        raise ReplayError("Lean-rendered native module differs from reviewed_module()")
    if output[len(module):] != corpus.read_text():
        raise ReplayError(f"stale native syntax corpus: regenerate {corpus.name} from QueryModuleExport")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lean", default="lean", help="pinned Lean executable")
    parser.add_argument("--variant-export", type=Path, help="write QueryVariantExport output here")
    arguments = parser.parse_args()
    here = Path(__file__).resolve().parent
    try:
        pin_match = re.fullmatch(
            rb"leanprover/lean4:v([0-9]+\.[0-9]+\.[0-9]+)",
            (here.parent / "lifecycle/lean-toolchain").read_bytes().strip(),
        )
        if pin_match is None:
            raise ReplayError("invalid Lean toolchain pin")
        pin = pin_match[1].decode("ascii")
        version = run([arguments.lean, "--version"], 30)
        if not re.search(rf"\bversion {re.escape(pin)}(?:,|\))", version):
            raise ReplayError(f"expected Lean {pin}")
        check_tamarin_version(run(["tamarin-prover", "--version"], 30))
        expanded = run_guarded_tamarin(
            ["tamarin-prover", "--parse-only", str(here.parent / "ratchet.spthy")], 120,
        )
        equations = reviewed_signature(expanded)
        with tempfile.TemporaryDirectory(prefix="cairn-equations-") as temporary:
            build = Path(temporary)
            environment = ["env", f"LEAN_PATH={build}"]
            outputs = []
            for module, theorems in (
                ("Termination", AUDITED_THEOREMS),
                ("Coherence", COHERENCE_THEOREMS),
                ("Boundedness", BOUNDEDNESS_THEOREMS),
                ("Confluence", CONFLUENCE_THEOREMS),
                ("Convergence", CONVERGENCE_THEOREMS),
                ("QueryImage", QUERY_IMAGE_THEOREMS),
                ("QueryRecognition", QUERY_RECOGNITION_THEOREMS),
                ("QueryAC", QUERY_AC_THEOREMS),
                ("QueryRewrite", QUERY_REWRITE_THEOREMS),
                ("QueryMatching", QUERY_MATCHING_THEOREMS),
                ("QuerySubstitution", QUERY_SUBSTITUTION_THEOREMS),
                ("QueryFraming", QUERY_FRAMING_THEOREMS),
                ("QueryRelabeling", QUERY_RELABELING_THEOREMS),
                ("QueryKind", QUERY_KIND_THEOREMS),
                ("QuerySorted", QUERY_SORTED_THEOREMS),
                ("QuerySortedConvergence", QUERY_SORTED_CONVERGENCE_THEOREMS),
                ("QuerySortedBoundedness", QUERY_SORTED_BOUNDEDNESS_THEOREMS),
                ("QuerySortedExact", QUERY_SORTED_EXACT_THEOREMS),
                ("QuerySortedGlobal", QUERY_SORTED_GLOBAL_THEOREMS),
                ("QuerySortedAC", QUERY_SORTED_AC_THEOREMS),
                ("QuerySortedQuotient", QUERY_SORTED_QUOTIENT_THEOREMS),
                ("QuerySortedSubstitution", QUERY_SORTED_SUBSTITUTION_THEOREMS),
                ("QueryKindSubstitution", QUERY_KIND_SUBSTITUTION_THEOREMS),
                ("QueryComposition", QUERY_COMPOSITION_THEOREMS),
                ("QueryUnification", QUERY_UNIFICATION_THEOREMS),
                ("QueryInstances", QUERY_INSTANCE_THEOREMS),
                ("QueryTypedInstances", QUERY_TYPED_INSTANCE_THEOREMS),
                ("QueryCompleteness", QUERY_COMPLETENESS_THEOREMS),
                ("QuerySupport", QUERY_SUPPORT_THEOREMS),
                ("QueryFiniteUnification", QUERY_FINITE_UNIFICATION_THEOREMS),
                ("QueryKindInstances", QUERY_KIND_INSTANCE_THEOREMS),
                ("QueryKindCompleteness", QUERY_KIND_COMPLETENESS_THEOREMS),
                ("QueryOccurs", QUERY_OCCURS_THEOREMS),
                ("QueryVariableBindings", QUERY_VARIABLE_BINDING_THEOREMS),
                ("QueryVariableGeneration", QUERY_VARIABLE_GENERATION_THEOREMS),
                ("QuerySystems", QUERY_SYSTEM_THEOREMS),
                ("QuerySortIntersection", QUERY_SORT_INTERSECTION_THEOREMS),
                ("QuerySortShapes", QUERY_SORT_SHAPE_THEOREMS),
                ("QuerySortRequirements", QUERY_SORT_REQUIREMENT_THEOREMS),
                ("QuerySortRefinement", QUERY_SORT_REFINEMENT_THEOREMS),
                ("QueryPrincipalSort", QUERY_PRINCIPAL_SORT_THEOREMS),
                ("QuerySortFingerprint", QUERY_SORT_FINGERPRINT_THEOREMS),
                ("QuerySystemBindings", QUERY_SYSTEM_BINDING_THEOREMS),
                ("QueryConstructors", QUERY_CONSTRUCTOR_THEOREMS),
                ("QueryConstructorSystems", QUERY_CONSTRUCTOR_SYSTEM_THEOREMS),
                ("NaturalMultiplicity", NATURAL_MULTIPLICITY_THEOREMS),
                ("NaturalLinearization", NATURAL_LINEARIZATION_THEOREMS),
                ("IntegerWords", additive_audits.INTEGER_WORD_THEOREMS),
                ("IntegerZeroSum", additive_audits.INTEGER_ZERO_SUM_THEOREMS),
                ("IntegerWordBasis", additive_audits.INTEGER_ROW_BASIS_THEOREMS),
                ("IntegerWordInclusion", additive_audits.INTEGER_INCLUSION_THEOREMS),
                ("IntegerWordPruning", additive_audits.INTEGER_PRUNING_THEOREMS),
                ("IntegerBasisCompleteness", additive_audits.INTEGER_PRUNING_COMPLETENESS_THEOREMS),
                ("IntegerBasisExtension", additive_audits.INTEGER_EXTENSION_THEOREMS),
                ("IntegerMatrixBasis", additive_audits.INTEGER_MATRIX_THEOREMS),
                ("IntegerWordExpansion", additive_audits.INTEGER_EXPANSION_THEOREMS),
                ("IntegerWordMixture", additive_audits.INTEGER_MIXTURE_THEOREMS),
                ("IntegerWordLinear", additive_audits.INTEGER_LINEAR_THEOREMS),
                ("IntegerMatrixFactors", additive_audits.INTEGER_FACTOR_THEOREMS),
                ("IntegerWordFamily", additive_audits.INTEGER_SELECTION_THEOREMS),
                ("IntegerMixtureAlgebra", additive_audits.INTEGER_MIXTURE_ALGEBRA_THEOREMS),
                ("IntegerMixtureSoundness", additive_audits.INTEGER_MIXTURE_SOUNDNESS_THEOREMS),
                ("IntegerFamilySoundness", additive_audits.INTEGER_FAMILY_SOUNDNESS_THEOREMS),
                ("IntegerFamilyCompleteness", additive_audits.INTEGER_FAMILY_COMPLETENESS_THEOREMS),
                ("IntegerMixtureComponents", additive_audits.INTEGER_COMPONENT_THEOREMS),
                ("IntegerMixtureTransport", additive_audits.INTEGER_MIXTURE_TRANSPORT_THEOREMS),
                ("IntegerRigidFamily", additive_audits.INTEGER_RIGID_CANDIDATE_THEOREMS),
                ("IntegerRigidAssignments", additive_audits.INTEGER_RIGID_ASSIGNMENT_THEOREMS),
                ("IntegerRigidWitness", additive_audits.INTEGER_RIGID_WITNESS_THEOREMS),
                ("IntegerRigidCompleteness", additive_audits.INTEGER_RIGID_COMPLETENESS_THEOREMS),
                ("IntegerRigidSoundness", additive_audits.INTEGER_RIGID_SOUNDNESS_THEOREMS),
                ("IntegerRigidScope", additive_audits.INTEGER_RIGID_SCOPE_THEOREMS),
                ("NaturalResiduals", additive_audits.NATURAL_RESIDUAL_THEOREMS),
                ("NaturalColumns", additive_audits.NATURAL_COLUMN_THEOREMS),
                ("NaturalSystemFamily", additive_audits.NATURAL_SYSTEM_GENERATOR_THEOREMS),
                ("NaturalBindings", additive_audits.NATURAL_BINDING_THEOREMS),
                ("NaturalAtomSubstitution", additive_audits.NATURAL_ATOM_SUBSTITUTION_THEOREMS),
                ("NaturalSystemScope", additive_audits.NATURAL_SYSTEM_SCOPE_THEOREMS),
                ("NaturalSystemRealization", additive_audits.NATURAL_SYSTEM_REALIZATION_THEOREMS),
                ("NaturalSystemCompleteness", additive_audits.NATURAL_SYSTEM_COMPLETENESS_THEOREMS),
                *general_audits.MODULES,
            ):
                output = run([
                    *environment, arguments.lean, "-DwarningAsError=true",
                    "-o", str(build / f"{module}.olean"), str(here / f"{module}.lean"),
                ], 120)
                if theorems:
                    check_axioms(
                        output, tuple(f"Cairn.Equations.{name}" for name in theorems),
                    )
                outputs.append(output.strip())
            for module in (
                "CoherenceCases", "BoundednessCases", "ConfluenceCases", "QueryImageCases",
                "QueryACCases", "QueryRewriteCases", "QuerySubstitutionCases", "QueryFramingCases",
                "QueryKindCases", "QuerySortedCases", "QuerySortedBoundednessCases",
                "QuerySortedQuotientCases",
                "QuerySortedSubstitutionCases",
                "QueryUnificationCases",
                "QueryInstanceCases",
                "QueryTypedInstanceCases",
                "QueryCompletenessCases",
                "QuerySupportCases",
                "QueryFiniteUnificationCases",
                "QueryKindInstanceCases",
                "QueryKindCompletenessCases",
                "QueryOccursCases",
                "QueryVariableBindingCases",
                "QuerySystemCases",
                "QuerySortRequirementCases",
                "QueryPrincipalSortCases",
                "QuerySystemBindingCases",
                "QueryConstructorCases",
                "NaturalMultiplicityCases",
                "NaturalCodeCases",
                "NaturalLinearizationCases",
                "IntegerWordCases",
                "IntegerFactorCases",
                "IntegerFamilyCases",
                "IntegerRigidCases",
                "NaturalResidualCases",
                "NaturalColumnCases",
                "NaturalSystemCases",
                "QueryGeneralCases",
                "QueryVariantCases",
                "QueryVariantExport",
                "QueryModuleExport",
            ):
                output = run([
                    *environment, arguments.lean, "-DwarningAsError=true",
                    str(here / f"{module}.lean"),
                ], 120)
                if module == "QueryVariantExport" and arguments.variant_export:
                    arguments.variant_export.write_text(output)
                if module == "QueryModuleExport":
                    check_module_export(output, here / "native-proxy/tests/syntax_corpus.txt")
            certificate = build / "SourceEquations.lean"
            certificate.write_text(lean_correspondence(equations))
            run([*environment, arguments.lean, "-DwarningAsError=true", str(certificate)], 120)
        digest = hashlib.sha256(expanded.encode()).hexdigest()
        print("\n".join(outputs))
        print(f"Lean {pin}; expanded theory SHA-256: {digest}")
        print("PASS: all six source equations terminate in every message context modulo natural AC.")
        print("PASS: matching modulo AC is sound and B-coherent in the same typed message algebra.")
        print("PASS: normalized substitutions have a source-template-only normalization bound.")
        print("PASS: matching is confluent and quotient rewrite paths join modulo natural AC.")
        print("PASS: typed frozen-index encoding round-trips without variable/constant collisions.")
        print("PASS: the encoded image preserves/reflects structural AC and six-rule/context rewriting.")
        print("PASS: encoded quotient steps are realizable by typed matching modulo AC.")
        print("PASS: typed natural/message substitutions commute with encoding and preserve its image.")
        print("PASS: free tuple/Node framing is closed under structural AC, rewriting and typed substitution.")
        print("PASS: fresh/natural kind abstraction is injective and transports AC/rewrite image evidence.")
        print("PASS: proper-sort native matching transfers convergence and the source-template bound.")
        print("PASS: guarded native query templates have a substitution-independent normalizing bound.")
        print("PASS: guarded native quotient paths terminate and converge modulo structural AC.")
        print("PASS: sort-respecting substitutions preserve guarded paths and controlled-kind framing.")
        print("PASS: sorted AC-unifier solutions compose and transfer through compatible typed images.")
        print("PASS: source-variable-scoped AC instances form a preorder and preserve sorted solutions.")
        print("PASS: complete AC-unifier families and most-generality transfer on proper typed images.")
        print("PASS: finite input restriction preserves exact substitutions and sorted assignments.")
        print("PASS: finite solution and residual-variable postfactor witnesses preserve AC completeness.")
        print("PASS: admissible kind-shadow factors lift constructively and preserve scoped AC instances.")
        print("PASS: complete kind-shadow families and most-generality transfer with admissible factors.")
        print("PASS: proper finite-AST occurrences exclude AC-unifiers and have complete empty families.")
        print("PASS: sort-compatible occurs-free variable bindings construct finite complete AC-unifier families.")
        print("PASS: proof-carrying variable equations generate complete finite binding families.")
        print("PASS: finite equation systems preserve scoped AC solutions and residual factorization.")
        print("PASS: finite sort requirements exactly characterize sorted substitutions over the full native AST.")
        print("PASS: principal residual sorts preserve every value-sort test through full-AST substitution.")
        print("PASS: finite binding composition and variable elimination preserve complete system families.")
        print("PASS: free-constructor decomposition and fixed-head clashes preserve complete system families.")
        print("PASS: natural AC equivalence is exactly equality of nonempty atom multiplicities.")
        print("PASS: natural substitutions solve AC exactly when their finite linear counts agree.")
        print("PASS: finite integer-matrix bases generate every homogeneous nonnegative solution.")
        print("PASS: homogeneous semigroup candidates are nonempty, sound and complete with nonempty factors.")
        print("PASS: rigid-column semigroup families preserve constants with complete nonempty factorization.")
        print("PASS: residual Nat indices are fresh, bounded and distinct on the generated basis.")
        print("PASS: concrete natural-system rows characterize sorted natural AC solutions exactly.")
        print("PASS: natural equation systems generate sound, complete finite native sorted binding families.")
        print("PASS: full-AST sorted AC systems generate finite complete families with fresh residuals and globally sorted postfactors.")
        print("PASS: guarded native query terms have finite complete variant families.")
        print("PASS: the native module text and six rule templates are rendered by Lean; parse∘render = id.")
        print("Scope: typed image algebra + Lean native-query FVP + enforced native stream membership; not a Maude variant-generator certificate.")
        print("Trust boundary: Tamarin/Maude + Rust stream guard + Python evidence/signature/translation + Lean kernel.")
        return 0
    except (OSError, RuntimeError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
