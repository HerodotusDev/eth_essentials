use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_EXPECTED_LEADING_ZEROES: &str = "assert ids.res == expected_leading_zeroes, f\"Expected {expected_leading_zeroes} but got {ids.res}\"";

fn hint_expected_leading_zeroes(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let res: Felt252 = utils::get_value("res", vm, hint_data)?;
    let expected_leading_zeroes: Felt252 = exec_scope.get("expected_leading_zeroes")?;

    if expected_leading_zeroes.ne(&res) {
        Err(HintError::AssertNotEqualFail(Box::new((
            MaybeRelocatable::Int(expected_leading_zeroes),
            MaybeRelocatable::Int(res),
        ))))
    } else {
        Ok(())
    }
}

#[distributed_slice(HINTS)]
static _HINT_EXPECTED_LEADING_ZEROS: Hint =
    (HINT_EXPECTED_LEADING_ZEROES, hint_expected_leading_zeroes);

const HINT_EXPECTED_NIBBLE: &str = "assert ids.extracted_nibble_at_pos == expected_nibble, f\"extracted_nibble_at_pos={ids.extracted_nibble_at_pos} expected_nibble={expected_nibble}\"";

fn hint_expected_nibble(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let extracted_nibble_at_pos: Felt252 =
        utils::get_value("extracted_nibble_at_pos", vm, hint_data)?;
    let expected_nibble: Felt252 = exec_scope.get("expected_nibble")?;

    if extracted_nibble_at_pos.ne(&expected_nibble) {
        Err(HintError::AssertNotEqualFail(Box::new((
            MaybeRelocatable::Int(extracted_nibble_at_pos),
            MaybeRelocatable::Int(expected_nibble),
        ))))
    } else {
        Ok(())
    }
}

#[distributed_slice(HINTS)]
static _HINT_EXPECTED_NIBBLE: Hint = (HINT_EXPECTED_NIBBLE, hint_expected_nibble);
