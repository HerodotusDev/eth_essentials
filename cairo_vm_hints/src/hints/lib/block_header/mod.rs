use std::{cmp::Ordering, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

const HINT_RLP_BIGINT_SIZE: &str = "memory[ap] = 1 if ids.byte <= 127 else 0";

const FELT_127: Felt252 = Felt252::from_hex_unchecked("0x7F");

fn hint_rlp_bigint_size(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match get_integer_from_var_name("byte", vm, &hint_data.ids_data, &hint_data.ap_tracking)?.cmp(&FELT_127) {
        Ordering::Less | Ordering::Equal => insert_value_into_ap(vm, MaybeRelocatable::Int(Felt252::ONE))?,
        Ordering::Greater => insert_value_into_ap(vm, MaybeRelocatable::Int(Felt252::ZERO))?,
    };

    Ok(())
}

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        HINT_RLP_BIGINT_SIZE => hint_rlp_bigint_size(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(hint_data.code.to_string().into_boxed_str())),
    }
}
