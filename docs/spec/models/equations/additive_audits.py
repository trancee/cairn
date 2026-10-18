"""Required Lean reports for finite additive generation and residual allocation."""

INTEGER_WORD_THEOREMS = (
    "integer_word_sum_append", "integer_word_sum_permutation", "integer_word_bounded_order",
)
INTEGER_ZERO_SUM_THEOREMS = ("integer_word_bounded_zero_sum",)
INTEGER_ROW_BASIS_THEOREMS = (
    "integer_alphabet_bound", "integer_bounded_words_iff",
    "integer_row_word_basis_sound", "integer_row_word_basis_complete",
)
INTEGER_INCLUSION_THEOREMS = ("integer_word_contains_iff",)
INTEGER_PRUNING_THEOREMS = (
    "integer_word_representative_member", "integer_word_representative_complete",
    "integer_primitive_basis_member", "integer_primitive_subword",
)
INTEGER_PRUNING_COMPLETENESS_THEOREMS = ("integer_primitive_basis_complete",)
INTEGER_EXTENSION_THEOREMS = (
    "integer_word_sum_flatten", "integer_basis_extension_sound", "integer_basis_extension_complete",
)
INTEGER_MATRIX_THEOREMS = (
    "integer_matrix_word_basis_sound", "integer_matrix_word_basis_complete",
)
INTEGER_EXPANSION_THEOREMS = (
    "integer_word_erase_duplicates_unique", "integer_word_expansion_scope",
    "integer_word_nodup_count", "integer_word_expansion_count",
    "integer_word_expansion_zero", "integer_word_expansion_permutation",
)
INTEGER_MIXTURE_THEOREMS = ("integer_word_mixture_count",)
INTEGER_FACTOR_THEOREMS = ("integer_matrix_word_factorization",)
INTEGER_SELECTION_THEOREMS = (
    "integer_word_selection_scope", "integer_word_selection_filter",
    "integer_matrix_word_family_nonempty",
)
INTEGER_MIXTURE_ALGEBRA_THEOREMS = (
    "integer_word_mixture_cons", "integer_word_mixture_congr",
    "integer_word_mixture_filter_nonempty", "integer_word_mixture_bind_singletons",
)
INTEGER_MIXTURE_SOUNDNESS_THEOREMS = (
    "integer_word_mixture_transpose", "integer_word_mixture_balanced",
)
INTEGER_FAMILY_SOUNDNESS_THEOREMS = ("integer_matrix_word_family_sound",)
INTEGER_FAMILY_COMPLETENESS_THEOREMS = ("integer_matrix_word_family_complete",)
INTEGER_COMPONENT_THEOREMS = (
    "integer_word_mixture_component", "integer_word_mixture_rigid_component",
)
INTEGER_MIXTURE_TRANSPORT_THEOREMS = (
    "integer_word_mixture_bind", "integer_word_mixture_map", "integer_word_mixture_relevant_congr",
)
INTEGER_RIGID_CANDIDATE_THEOREMS = (
    "integer_rigid_word_family_nonempty", "integer_rigid_word_family_constants",
)
INTEGER_RIGID_ASSIGNMENT_THEOREMS = ("integer_word_rigid_assignments_complete",)
INTEGER_RIGID_WITNESS_THEOREMS = (
    "integer_word_rigid_choice_allowed", "integer_word_rigid_postfactor_nonempty",
    "integer_word_rigid_choice_instantiation", "integer_word_rigid_choice_ground",
)
INTEGER_RIGID_COMPLETENESS_THEOREMS = ("integer_rigid_word_family_complete",)
INTEGER_RIGID_SOUNDNESS_THEOREMS = ("integer_rigid_word_family_sound",)
NATURAL_RESIDUAL_THEOREMS = (
    "natural_fresh_base_bound", "natural_residual_index_fresh",
    "natural_residual_index_range", "natural_residual_index_injective",
)
INTEGER_LINEAR_THEOREMS = (
    "integer_word_sum_add", "integer_word_sum_subtract", "integer_word_sum_congr",
    "integer_word_sum_indicator", "integer_word_count_pairing", "integer_word_flatmap_count",
    "integer_word_equation_counts",
)
NATURAL_COLUMN_THEOREMS = (
    "natural_column_values_nonempty", "natural_template_column_substitution",
    "natural_system_columns_scope", "natural_system_columns_unique",
    "natural_system_rigid_scope", "natural_system_rigid_values", "natural_system_rows_iff",
)
INTEGER_RIGID_SCOPE_THEOREMS = (
    "integer_word_rigid_assignments_scope", "integer_rigid_word_family_name_scope",
    "integer_rigid_word_family_map_sound",
)
NATURAL_SYSTEM_GENERATOR_THEOREMS = ("natural_system_residual_code_fresh",)
NATURAL_BINDING_THEOREMS = ("natural_bindings_encode", "natural_bindings_realization")
NATURAL_ATOM_SUBSTITUTION_THEOREMS = (
    "natural_substitution_atom_codes", "natural_atom_image_rigid",
    "natural_atom_image_variable", "natural_residual_factor_realization",
)
NATURAL_SYSTEM_SCOPE_THEOREMS = (
    "natural_variable_indices_iff", "natural_rigid_columns_iff", "natural_system_rigid_codes_even",
    "native_natural_variables_iff", "native_natural_system_scope", "natural_system_scope_keys",
)
NATURAL_SYSTEM_REALIZATION_THEOREMS = (
    "natural_system_candidate_realization", "natural_system_factor_realization",
)
NATURAL_SYSTEM_COMPLETENESS_THEOREMS = (
    "native_natural_system_rows_iff", "native_natural_system_family_sound",
    "native_natural_system_family_complete",
)
