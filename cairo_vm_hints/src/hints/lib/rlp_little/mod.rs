use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

mod assert;
mod divmod;
mod leading_zeros;
mod nibbles;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        assert::HINT_EXPECTED_LEADING_ZEROES => {
            assert::hint_expected_leading_zeroes(vm, exec_scope, hint_data, constants)
        }
        assert::HINT_EXPECTED_NIBBLE => {
            assert::hint_expected_nibble(vm, exec_scope, hint_data, constants)
        }
        divmod::HINT_POW_CUT => divmod::hint_pow_cut(vm, exec_scope, hint_data, constants),
        leading_zeros::HINT_EXPECTED_LEADING_ZEROES => {
            leading_zeros::hint_expected_leading_zeroes(vm, exec_scope, hint_data, constants)
        }
        leading_zeros::HINT_EXPECTED_NIBBLE => {
            leading_zeros::hint_expected_nibble(vm, exec_scope, hint_data, constants)
        }
        nibbles::HINT_IS_ZERO => nibbles::hint_is_zero(vm, exec_scope, hint_data, constants),
        nibbles::HINT_NIBBLE_FROM_LOW => {
            nibbles::hint_nibble_from_low(vm, exec_scope, hint_data, constants)
        }
        nibbles::HINT_NEEDS_NEXT_WORD => {
            nibbles::hint_needs_next_word(vm, exec_scope, hint_data, constants)
        }
        nibbles::HINT_NEEDS_NEXT_WORD_ENDING => {
            nibbles::hint_needs_next_word_ending(vm, exec_scope, hint_data, constants)
        }
        nibbles::HINT_WORDS_LOOP => nibbles::hint_words_loop(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
