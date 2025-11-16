use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use starknet_types_core::felt::Felt;

pub const MMR_LEFT_CHILD: &str = "ids.in_mmr = 1 if ids.left_child <= ids.mmr_len else 0";

pub fn mmr_left_child(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_child = get_integer_from_var_name("left_child", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let mmr_len = get_integer_from_var_name("mmr_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let in_mmr = if left_child <= mmr_len { Felt::ONE } else { Felt::ZERO };
    insert_value_from_var_name(
        "in_mmr",
        MaybeRelocatable::Int(in_mmr),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}
