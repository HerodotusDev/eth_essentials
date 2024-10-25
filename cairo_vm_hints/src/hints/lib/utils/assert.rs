use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::get_constant_from_var_name;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_ASSERT_INTEGER_DIV32: &str = "from starkware.cairo.common.math_utils import assert_integer\nassert_integer(ids.DIV_32)\nif not (0 < ids.DIV_32 <= PRIME):\n    raise ValueError(f'div={hex(ids.DIV_32)} is out of the valid range.')";

fn hint_assert_integer_div32(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let div_32: Felt252 = utils::get_value("DIV_32", vm, hint_data)?;
    let prime: Felt252 = *get_constant_from_var_name("PRIME", constants)?;

    if Felt252::ZERO < div_32 && div_32 <= prime {
        Err(HintError::AssertNNValueOutOfRange(Box::new(prime)))
    } else {
        Ok(())
    }
}

#[distributed_slice(HINTS)]
static _HINT_ASSERT_INTEGER_DIV32: Hint = (HINT_ASSERT_INTEGER_DIV32, hint_assert_integer_div32);

const HINT_ASSERT_INTEGER_DIV: &str = "from starkware.cairo.common.math_utils import assert_integer\nassert_integer(ids.div)\nif not (0 < ids.div <= PRIME):\n    raise ValueError(f'div={hex(ids.div)} is out of the valid range.')";

fn hint_assert_integer_div(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let div: Felt252 = utils::get_value("div", vm, hint_data)?;
    let prime: Felt252 = *get_constant_from_var_name("PRIME", constants)?;

    if Felt252::ZERO < div && div <= prime {
        Err(HintError::AssertNNValueOutOfRange(Box::new(prime)))
    } else {
        Ok(())
    }
}

#[distributed_slice(HINTS)]
static _HINT_ASSERT_INTEGER_DIV: Hint = (HINT_ASSERT_INTEGER_DIV, hint_assert_integer_div);
