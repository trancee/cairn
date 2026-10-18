"""Independent literal audit transcripts for unrestricted sorted AC generation."""

GENERAL_REPORT_GROUPS = {
    "unrestricted-values": (
        "native_sorted_value_ac_iff", "native_unrestricted_sort_fingerprint_substitution",
        "native_sorted_substitution_variable_proper",
    ),
    "residual-retyping": (
        "native_bindings_sorted_of_values", "native_bindings_sorted_check", "native_binding_lookup_map",
        "native_residual_retag_functional", "native_retag_candidate_assignment", "native_residual_keys_cover",
    ),
    "residual-realization": ("native_residual_retyping_realization",),
    "sorted-generation": (
        "native_raw_system_assignment_eq_on", "native_sorted_binding_family_sound",
        "native_sorted_binding_family_complete",
    ),
    "source-terms": (
        "native_subterms_self", "native_subterms_children", "native_subterms_transitive",
        "native_system_subterms_children", "native_system_subterms_roots", "native_variable_subterm",
        "native_system_variable_subterm", "native_variable_subterm_iff", "native_system_variable_subterm_iff",
    ),
    "ac-words": (
        "native_ac_class_eq_iff", "native_ac_class_add_associative", "native_ac_class_add_commutative",
        "native_ac_word_append", "native_ac_word_permutation", "native_ac_atom_word_nonempty",
        "native_ac_atom_word_value", "native_ac_atom_word_iff",
        "native_ac_class_weight_positive", "native_ac_class_weight_add",
    ),
    "natural-interpretation": (
        "native_natural_interpret_ac", "native_natural_interpret_substitution",
        "native_natural_rigid_codes", "native_natural_rigid_weight",
    ),
    "finite-rendering": (
        "native_mapM_exact", "native_mapM_exists", "native_mapM_member", "native_mapM_preserve",
        "native_marker_removal_shorter", "native_filterMap_congr", "native_mapM_congr", "native_find_congr",
    ),
    "natural-rendering": (
        "native_render_natural_interpretation", "native_render_natural_preserve",
        "native_render_natural_exists", "native_render_natural_unique",
    ),
    "raw-plans": (
        "native_raw_label_map", "native_raw_label_words_iff", "native_raw_label_bound",
        "native_raw_rigid_equation", "native_raw_node_equation_member",
    ),
    "marker-rendering": (
        "native_raw_marker_render_unique", "native_raw_marker_render_member",
        "native_raw_representative_member", "native_raw_representative_label",
        "native_raw_representative_exists",
    ),
    "source-realization": (
        "native_build_query_node", "native_rebuild_query_node_equal",
        "native_source_term_realization", "native_source_child_substitution_count",
    ),
    "marker-realization": (
        "native_raw_partial_marker_value", "native_raw_render_class_value", "native_raw_marker_shape",
    ),
    "raw-soundness": (
        "native_raw_auxiliary_interpretation", "native_raw_render_bindings_sound",
        "native_raw_ac_system_family_sound",
    ),
    "natural-rigid-scope": (
        "native_natural_candidate_rigid_scope", "native_raw_class_scope", "native_raw_node_rigid_scope",
        "native_raw_auxiliary_rigid_scope", "native_raw_candidate_marker_scope",
    ),
    "solution-labels": (
        "native_solution_label_bound", "native_solution_label_ac", "native_solution_label_reflection",
        "native_solution_source_value", "native_solution_label_word", "native_rigid_substitution_head",
        "native_rigid_substitution_children", "native_children_ac_map_eq", "native_solution_plan_consistent",
    ),
    "atom-models": (
        "native_atom_model_codes_nonempty", "native_atom_model_codes", "native_atom_model_ac",
        "native_atom_model_add", "native_natural_code_word", "native_natural_code_rigid",
        "native_class_decoder", "native_atom_model_interpretation",
    ),
    "solution-models": (
        "native_solution_atom_covered", "native_solution_source_covered", "native_solution_decoder",
        "native_solution_model_class", "native_solution_rigid_model", "native_solution_add_model",
        "native_solution_model_node", "native_solution_natural_model",
    ),
    "solution-factors": ("native_solution_auxiliary_factor",),
    "rendering-factors": (
        "native_render_natural_factor", "native_rebuild_query_node_ac",
        "native_rigid_rebuild_substitution", "native_rigid_source_rebuild",
    ),
    "marker-completeness": ("native_solution_marker_dependency", "native_solution_marker_complete"),
    "binding-rendering": ("native_binding_mapM_lookup",),
    "plan-congruence": (
        "native_raw_child_labels_congr", "native_raw_natural_system_congr",
        "native_raw_plan_consistent_congr", "native_raw_markers_congr", "native_raw_representative_congr",
        "native_raw_marker_congr", "native_raw_render_bindings_congr",
    ),
    "raw-realization": ("native_solution_raw_bindings",),
    "residual-freshness": (
        "native_residual_retag_fresh", "native_substitution_residual_fresh",
        "native_retag_candidate_fresh", "native_sorted_binding_family_fresh",
    ),
    "general-ac-completeness": (
        "native_raw_ac_system_family_complete", "native_sorted_ac_system_family_complete",
        "native_sorted_ac_system_family_sound", "native_sorted_ac_system_family_fresh",
    ),
}
