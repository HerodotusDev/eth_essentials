use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData, hint_utils::get_constant_from_var_name,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use starknet_types_core::felt::NonZeroFelt;

use crate::utils;

const FELT_8: Felt252 = Felt252::from_hex_unchecked("0x08");

pub const HINT_VALUE_DIV32: &str = "ids.q, ids.r = divmod(ids.value, ids.DIV_32)";

pub fn hint_value_div32(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value: Felt252 = utils::get_value("value", vm, hint_data)?;
    let div_32: Felt252 = *get_constant_from_var_name("DIV_32", constants)?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(div_32).unwrap());
    utils::write_value("q", q, vm, hint_data)?;
    utils::write_value("r", r, vm, hint_data)
}

pub const HINT_VALUE_8: &str = "ids.q, ids.r = divmod(ids.value, 8)";

pub fn hint_value_8(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value: Felt252 = utils::get_value("value", vm, hint_data)?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(FELT_8).unwrap());
    utils::write_value("q", q, vm, hint_data)?;
    utils::write_value("r", r, vm, hint_data)
}

pub const HINT_VALUE_DIV: &str = "ids.q, ids.r = divmod(ids.value, ids.div)";

pub fn hint_value_div(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value: Felt252 = utils::get_value("value", vm, hint_data)?;
    let div: Felt252 = utils::get_value("div", vm, hint_data)?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(div).unwrap());
    utils::write_value("q", q, vm, hint_data)?;
    utils::write_value("r", r, vm, hint_data)
}
