use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_integer_from_var_name, insert_value_from_var_name};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use starknet_types_core::felt::Felt;
use std::collections::HashMap;

pub const HINT_IS_POSITION_IN_MMR_ARRAY: &str = "ids.is_position_in_mmr_array= 1 if ids.position > ids.mmr_offset else 0";

pub fn hint_is_position_in_mmr_array(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let position = get_integer_from_var_name("position", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let mmr_offset = get_integer_from_var_name("mmr_offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let is_position_in_mmr_array = if position > mmr_offset { Felt::ONE } else { Felt::ZERO };
    insert_value_from_var_name(
        "is_position_in_mmr_array",
        MaybeRelocatable::Int(is_position_in_mmr_array),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}
