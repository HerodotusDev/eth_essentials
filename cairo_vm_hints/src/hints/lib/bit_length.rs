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

pub const HINT_BIT_LENGTH: &str = "ids.bit_length = ids.x.bit_length()";

pub fn hint_bit_length(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x = get_integer_from_var_name("x", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name(
        "bit_length",
        MaybeRelocatable::Int(x.bits().into()),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        HINT_BIT_LENGTH => hint_bit_length(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(hint_data.code.to_string().into_boxed_str())),
    }
}
