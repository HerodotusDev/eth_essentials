use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use starknet_types_core::felt::NonZeroFelt;
use std::collections::HashMap;

const FELT_8: Felt252 = Felt252::from_hex_unchecked("0x08");

const HINT_VALUE_DIV32: &str = "ids.q, ids.r = divmod(ids.value, ids.DIV_32)";

fn hint_value_div32(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value: Felt252 = utils::get_value("value", vm, hint_data)?;
    let div_32: Felt252 = utils::get_value("DIV_32", vm, hint_data)?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(div_32).unwrap());
    utils::write_value("q", q, vm, hint_data)?;
    utils::write_value("r", r, vm, hint_data)
}

#[distributed_slice(HINTS)]
static _HINT_VALUE_DIV32: Hint = (HINT_VALUE_DIV32, hint_value_div32);

const HINT_VALUE_8: &str = "ids.q, ids.r = divmod(ids.value, 8)";

fn hint_value_8(
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

#[distributed_slice(HINTS)]
static _HINT_VALUE_8: Hint = (HINT_VALUE_8, hint_value_8);

const HINT_VALUE_DIV: &str = "ids.q, ids.r = divmod(ids.value, ids.div)";

fn hint_value_div(
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

#[distributed_slice(HINTS)]
static _HINT_VALUE_DIV: Hint = (HINT_VALUE_DIV, hint_value_div);
