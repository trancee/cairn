"""Independent theorem-report transcripts for the public equation checker."""

REPORT_GROUPS = {
    "termination": (
        "natural_ac_preserves_weight", "message_ac_preserves_weight",
        "primitive_rewrite_decreases_weight", "rewrite_decreases_weight",
        "modulo_ac_rewrite_decreases_weight", "modulo_ac_termination",
    ),
    "coherence": (
        "modulo_ac_matching_coherence", "matching_primitive_modulo_ac",
        "matching_rewrite_modulo_ac", "matching_termination", "matching_rewrite_ac_coherent",
    ),
    "boundedness": (
        "matching_steps_transitive", "matching_steps_context", "normalized_substitution_bound",
    ),
    "confluence": (
        "matching_local_confluence", "matching_steps_do_not_increase_weight", "matching_confluence",
    ),
    "convergence": (
        "normal_ac_invariant", "matching_steps_ac_coherent", "matching_normal_forms_unique",
        "modulo_ac_steps_matching", "modulo_ac_confluence",
    ),
    "query-image": (
        "native_natural_round_trip", "native_message_round_trip",
        "native_natural_encoding_injective", "native_message_encoding_injective",
    ),
    "native-algebra": (
        "native_natural_recognition", "native_message_recognition",
        "native_natural_ac_preservation", "native_message_ac_preservation",
        "native_natural_ac_reflection", "native_message_ac_reflection",
        "native_ac_natural_image", "native_ac_message_image",
        "native_primitive_preservation", "native_rewrite_preservation",
        "native_rewrite_decode", "native_rewrite_image", "native_rewrite_reflection",
        "native_modulo_ac_preservation", "native_modulo_ac_decode", "native_modulo_ac_reflection",
        "native_matching_preservation", "native_matching_realization",
    ),
    "substitution": (
        "native_natural_substitution", "native_message_substitution",
        "native_natural_substitution_image", "native_message_substitution_image",
        "native_ac_substitution", "native_rewrite_substitution",
    ),
    "framing": (
        "native_framed_ac", "native_framed_rewrite", "native_framed_substitution",
    ),
    "relabeling": (
        "native_ac_relabeling", "native_rewrite_relabeling", "native_modulo_ac_relabeling",
    ),
    "kind": (
        "native_kind_round_trip", "native_kind_abstraction_injective",
        "native_kind_substitution", "native_kind_framed_substitution",
        "native_kind_ac_reflection", "native_kind_rewrite_reflection",
        "native_kind_modulo_ac_reflection", "native_kind_framed_ac", "native_kind_framed_rewrite",
        "native_kind_modulo_ac_decode", "native_kind_termination",
    ),
    "sorted-matching": (
        "native_sorted_matching_preservation", "native_sorted_rewrite_modulo_ac",
        "native_sorted_rewrite_decode", "native_sorted_kind_framed_rewrite",
        "native_sorted_proper_termination", "native_sorted_kind_termination",
    ),
    "sorted-convergence": (
        "native_sorted_ac_coherent", "native_sorted_steps_preservation", "native_sorted_steps_decode",
        "native_sorted_normal_iff", "native_sorted_normal_ac_invariant", "native_sorted_confluence",
        "native_sorted_normal_forms_unique", "native_sorted_normalized_substitution_bound",
    ),
    "sorted-query-bound": (
        "native_sorted_steps_transitive", "native_sorted_steps_context",
        "native_sorted_query_substitution_bound",
    ),
    "sorted-exact": (
        "native_sorted_primitive_image", "native_sorted_rewrite_matching_decode",
        "native_sorted_steps_matching_decode", "native_sorted_proper_confluence_exact",
    ),
    "sorted-global": (
        "native_sorted_rewrite_decreases_count", "native_sorted_termination",
        "native_sorted_local_confluence", "native_sorted_steps_count_bound",
        "native_sorted_matching_confluence",
    ),
    "sorted-ac": (
        "native_query_ac_preserves_count", "native_sorted_query_ac_coherent",
    ),
    "sorted-quotient": (
        "native_sorted_query_normal_ac_invariant", "native_sorted_query_steps_ac_coherent",
        "native_sorted_modulo_ac_termination", "native_sorted_modulo_ac_normal_iff",
        "native_sorted_modulo_ac_steps_matching", "native_sorted_modulo_ac_confluence",
        "native_sorted_modulo_ac_normal_forms_unique",
    ),
    "sorted-substitution": (
        "native_typed_assignment_sorted", "native_sorted_assignment_representation",
        "native_sorted_proper_substitution", "native_sorted_rewrite_substitution",
        "native_sorted_steps_substitution", "native_sorted_modulo_ac_substitution",
        "native_sorted_modulo_ac_steps_substitution",
    ),
    "kind-substitution": (
        "native_kind_natural_image", "native_kind_proper_image",
        "native_kind_assignment_sorted", "native_kind_shadow_representation",
        "native_kind_sorted_framed_substitution",
    ),
    "assignment-algebra": (
        "native_substitution_identity", "native_substitution_composition",
        "native_sorted_value_substitution", "native_sorted_composition",
        "native_composition_associative", "native_substitution_assignment_ac",
    ),
    "sorted-unifiers": (
        "native_ac_unifier_composition", "native_message_ac_unifier_iff",
        "native_natural_ac_unifier_iff", "native_message_ac_unifier_representation",
        "native_natural_ac_unifier_representation",
    ),
    "kind-unifiers": (
        "native_kind_ac_unifier_iff", "native_kind_ac_unifier_representation",
    ),
    "scoped-instances": (
        "native_substitution_assignment_ac_on", "native_ac_instance_reflexive",
        "native_ac_instance_transitive", "native_ac_unifier_instance",
    ),
    "typed-instances": (
        "native_query_composition", "native_query_ac_leaf",
        "native_query_assignment_ac_on_iff", "native_query_ac_instance_iff",
    ),
    "complete-unifiers": (
        "native_singleton_complete_iff", "query_singleton_complete_iff",
        "native_message_complete_unifiers_iff", "native_natural_complete_unifiers_iff",
        "native_message_most_general_iff", "native_natural_most_general_iff",
    ),
}
