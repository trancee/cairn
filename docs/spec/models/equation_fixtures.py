"""Independent theorem-report transcripts for the public equation checker."""

from equation_general_fixtures import GENERAL_REPORT_GROUPS

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
        "native_identity_assignment_sorted",
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
    "finite-support": (
        "native_substitution_eq_on", "native_restriction_supported",
        "native_restriction_sorted", "native_restriction_substitution",
        "native_bindings_restriction", "native_bindings_supported",
        "native_restriction_finite",
    ),
    "finite-unifiers": (
        "native_ac_instance_finite_factor_iff", "native_ac_instance_restriction_iff",
        "native_ac_unifier_restriction_iff", "native_ac_unifier_finite_representation",
        "native_complete_unifiers_restriction_iff", "native_complete_unifiers_finite_solutions_iff",
        "native_most_general_finite_solutions_iff",
    ),
    "kind-instances": (
        "native_kind_assignment_round_trip", "native_kind_assignment_injective",
        "native_kind_composition", "native_kind_admissible_iff",
        "native_kind_admissible_sorted", "native_kind_admissible_composition",
        "native_kind_assignment_lookup", "native_kind_query_variables",
        "native_kind_assignment_ac_on_iff",
        "native_kind_ac_instance_iff", "native_kind_admissible_unifier_iff",
    ),
    "kind-families": (
        "native_kind_singleton_complete_iff", "native_kind_complete_unifiers_iff",
        "native_kind_most_general_iff",
    ),
    "occurs-check": (
        "native_occurrence_substitution_count", "native_proper_occurrence_substitution_count",
        "native_ac_unifier_occurs_check", "native_occurs_complete_empty_family",
    ),
    "variable-bindings": (
        "native_single_binding_sorted_iff", "native_single_binding_finite",
        "native_single_binding_supported", "native_single_binding_fixes_value",
        "native_single_binding_idempotent", "native_single_binding_unifier",
        "native_single_binding_factorization", "native_single_binding_most_general",
        "native_single_binding_complete_family", "native_single_binding_reversed_complete_family",
    ),
    "variable-generation": (
        "native_reflexive_complete_family", "native_variable_binding_family_complete",
        "native_variable_binding_family_finite",
    ),
    "equation-systems": (
        "native_system_cons_iff", "native_system_singleton_complete_iff",
        "native_system_substitution_iff", "native_system_assignment_ac",
        "native_system_assignment_eq_on",
        "native_system_empty_complete", "native_system_reflexive_complete_iff",
        "native_ac_instance_prefix", "native_system_swap_complete_iff",
    ),
    "system-bindings": (
        "native_bindings_composition", "native_finite_assignment_composition",
        "native_system_variable_elimination", "native_system_reversed_variable_elimination",
        "native_system_single_binding_complete", "native_system_occurs_complete_empty_family",
    ),
    "free-constructors": (
        "native_query_ac_head", "native_query_ac_free_children", "native_query_ac_constructor_iff",
        "native_ac_unary_iff", "native_ac_binary_iff", "native_ac_kdf_iff",
        "native_ac_list_iff", "native_ac_cons_iff",
    ),
    "constructor-systems": (
        "native_system_unary_decomposition", "native_system_binary_decomposition",
        "native_system_kdf_decomposition", "native_system_list_decomposition",
        "native_system_cons_decomposition", "native_substitution_fixed_head",
        "native_system_constructor_clash",
        "native_constructor_decomposition_complete", "native_constructor_decomposition_decreases",
        "native_constructor_decomposition_termination",
    ),
    "natural-multiplicity": (
        "natural_atom_codes_nonempty", "natural_ac_atoms_iff",
        "natural_ac_multiplicity_iff", "natural_multiplicity_add",
    ),
    "natural-linearization": (
        "natural_linear_count_substitution", "natural_linear_unifier_iff",
    ),
    "integer-words": (
        "integer_word_sum_append", "integer_word_sum_permutation", "integer_word_bounded_order",
    ),
    "integer-zero-sum": (
        "integer_word_bounded_zero_sum",
    ),
    "integer-row-basis": (
        "integer_alphabet_bound", "integer_bounded_words_iff",
        "integer_row_word_basis_sound", "integer_row_word_basis_complete",
    ),
    "integer-inclusion": (
        "integer_word_contains_iff",
    ),
    "integer-pruning": (
        "integer_word_representative_member", "integer_word_representative_complete",
        "integer_primitive_basis_member", "integer_primitive_subword",
    ),
    "integer-pruning-completeness": (
        "integer_primitive_basis_complete",
    ),
    "integer-extension": (
        "integer_word_sum_flatten", "integer_basis_extension_sound", "integer_basis_extension_complete",
    ),
    "integer-matrix": (
        "integer_matrix_word_basis_sound", "integer_matrix_word_basis_complete",
    ),
    "integer-expansion": (
        "integer_word_erase_duplicates_unique", "integer_word_expansion_scope",
        "integer_word_nodup_count", "integer_word_expansion_count",
        "integer_word_expansion_zero", "integer_word_expansion_permutation",
    ),
    "integer-mixture": ("integer_word_mixture_count",),
    "integer-factors": ("integer_matrix_word_factorization",),
    "integer-selections": (
        "integer_word_selection_scope", "integer_word_selection_filter",
        "integer_matrix_word_family_nonempty",
    ),
    "integer-mixture-algebra": (
        "integer_word_mixture_cons", "integer_word_mixture_congr",
        "integer_word_mixture_filter_nonempty", "integer_word_mixture_bind_singletons",
    ),
    "integer-mixture-soundness": (
        "integer_word_mixture_transpose", "integer_word_mixture_balanced",
    ),
    "integer-family-soundness": ("integer_matrix_word_family_sound",),
    "integer-family-completeness": ("integer_matrix_word_family_complete",),
    "integer-components": (
        "integer_word_mixture_component", "integer_word_mixture_rigid_component",
    ),
    "integer-mixture-transport": (
        "integer_word_mixture_bind", "integer_word_mixture_map", "integer_word_mixture_relevant_congr",
    ),
    "integer-rigid-candidates": (
        "integer_rigid_word_family_nonempty", "integer_rigid_word_family_constants",
    ),
    "integer-rigid-assignments": ("integer_word_rigid_assignments_complete",),
    "integer-rigid-witness": (
        "integer_word_rigid_choice_allowed", "integer_word_rigid_postfactor_nonempty",
        "integer_word_rigid_choice_instantiation", "integer_word_rigid_choice_ground",
    ),
    "integer-rigid-completeness": ("integer_rigid_word_family_complete",),
    "integer-rigid-soundness": ("integer_rigid_word_family_sound",),
    "natural-residuals": (
        "natural_fresh_base_bound", "natural_residual_index_fresh",
        "natural_residual_index_range", "natural_residual_index_injective",
    ),
    "natural-codec": (
        "natural_codes_decode_empty", "natural_codes_decode_exact", "natural_codes_decode_exists",
    ),
    "integer-linear": (
        "integer_word_sum_add", "integer_word_sum_subtract", "integer_word_sum_congr",
        "integer_word_sum_indicator", "integer_word_count_pairing", "integer_word_flatmap_count",
        "integer_word_equation_counts",
    ),
    "natural-columns": (
        "natural_column_values_nonempty", "natural_template_column_substitution",
        "natural_system_columns_scope", "natural_system_columns_unique",
        "natural_system_rigid_scope", "natural_system_rigid_values", "natural_system_rows_iff",
    ),
    "integer-rigid-scope": (
        "integer_word_rigid_assignments_scope", "integer_rigid_word_family_name_scope",
        "integer_rigid_word_family_map_sound",
    ),
    "natural-system-generator": ("natural_system_residual_code_fresh",),
    "natural-bindings": ("natural_bindings_encode", "natural_bindings_realization"),
    "natural-atom-substitution": (
        "natural_substitution_atom_codes", "natural_atom_image_rigid",
        "natural_atom_image_variable", "natural_residual_factor_realization",
    ),
    "natural-system-scope": (
        "natural_variable_indices_iff", "natural_rigid_columns_iff", "natural_system_rigid_codes_even",
        "native_natural_variables_iff", "native_natural_system_scope", "natural_system_scope_keys",
    ),
    "natural-system-realization": (
        "natural_system_candidate_realization", "natural_system_factor_realization",
    ),
    "natural-system-completeness": (
        "native_natural_system_rows_iff", "native_natural_system_family_sound",
        "native_natural_system_family_complete",
    ),
    "sort-intersection": ("native_sorted_value_check_iff", "native_sort_intersection_iff"),
    "sort-shapes": (
        "native_sorted_add_shape", "native_sorted_unary_shape",
        "native_sorted_binary_shape", "native_sorted_kdf_shape",
    ),
    "sort-requirements": (
        "native_sort_requirements_append_iff", "native_ground_sort_requirements_iff",
    ),
    "sort-refinement": ("native_sort_requirements_iff",),
    "principal-sort": ("native_principal_sort_iff",),
    "sort-fingerprint": ("native_sort_fingerprint_substitution",),
    **GENERAL_REPORT_GROUPS,
}
