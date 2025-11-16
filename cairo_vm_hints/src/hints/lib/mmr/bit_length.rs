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

pub const MMR_BIT_LENGTH: &str = "ids.bit_length = ids.mmr_len.bit_length()";

pub fn mmr_bit_length(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x = get_integer_from_var_name("mmr_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name(
        "bit_length",
        MaybeRelocatable::Int(x.bits().into()),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}
