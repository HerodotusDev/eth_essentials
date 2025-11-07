use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_integer_from_var_name, insert_value_from_var_name};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::HashMap;

pub const MMR_LEFT_CHILD: &str = "ids.in_mmr = 1 if ids.left_child <= ids.mmr_len else 0";

pub fn mmr_left_child(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_child = get_integer_from_var_name("left_child", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let mmr_len = get_integer_from_var_name("mmr_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let in_mmr: Felt252 = if left_child <= mmr_len { Felt252::from(1) } else { Felt252::from(0) };
    insert_value_from_var_name("in_mmr", MaybeRelocatable::Int(in_mmr), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    Ok(())
}
