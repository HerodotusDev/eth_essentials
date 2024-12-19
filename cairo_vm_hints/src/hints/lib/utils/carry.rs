use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use num_bigint::BigUint;
use std::collections::HashMap;

pub const HINT_CARRY: &str = "sum_low = ids.a.low + ids.b.low\nids.carry_low = 1 if sum_low >= ids.SHIFT else 0\nsum_high = ids.a.high + ids.b.high + ids.carry_low\nids.carry_high = 1 if sum_high >= ids.SHIFT else 0";

pub fn hint_carry(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let a_low: BigUint = utils::get_value("a.low", vm, hint_data)?.to_biguint();
    let a_high: BigUint = utils::get_value("a.high", vm, hint_data)?.to_biguint();
    let b_low: BigUint = utils::get_value("b.low", vm, hint_data)?.to_biguint();
    let b_high: BigUint = utils::get_value("b.high", vm, hint_data)?.to_biguint();
    let shift: BigUint = utils::get_value("SHIFT", vm, hint_data)?.to_biguint();

    utils::write_value(
        "carry_low",
        if a_low + b_low >= shift { Felt252::ONE } else { Felt252::ZERO },
        vm,
        hint_data,
    )?;

    utils::write_value(
        "carry_high",
        if a_high + b_high >= shift { Felt252::ONE } else { Felt252::ZERO },
        vm,
        hint_data,
    )?;

    Ok(())
}
