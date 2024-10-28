use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

mod bit_length;
mod left_child;
mod peak_values;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        bit_length::MMR_BIT_LENGTH => {
            bit_length::mmr_bit_length(vm, exec_scope, hint_data, constants)
        }
        left_child::MMR_LEFT_CHILD => {
            left_child::mmr_left_child(vm, exec_scope, hint_data, constants)
        }
        peak_values::HINT_IS_POSITION_IN_MMR_ARRAY => {
            peak_values::hint_is_position_in_mmr_array(vm, exec_scope, hint_data, constants)
        }
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
