use crate::hints::{Hint, HINTS};
use crate::utils::{get_value, write_value};
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_BIT_LENGTH_ASSIGN_140: &str = "ids.bit_length = 140";

fn hint_bit_length_assign_140(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    write_value(
        "bit_length",
        MaybeRelocatable::Int(Felt252::from_hex_unchecked("0x8C")),
        vm,
        hint_data,
    )?;

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_BIT_LENGTH_ASSIGN_140: Hint = (HINT_BIT_LENGTH_ASSIGN_140, hint_bit_length_assign_140);

const HINT_BIT_LENGTH_ASSIGN_NEGATIVE_ONE: &str = "ids.bit_length = -1";

fn hint_bit_length_assign_negative_one(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    write_value(
        "bit_length",
        MaybeRelocatable::Int(Felt252::ZERO - Felt252::ONE),
        vm,
        hint_data,
    )?;

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_BIT_LENGTH_ASSIGN_NEGATIVE_ONE: Hint = (
    HINT_BIT_LENGTH_ASSIGN_NEGATIVE_ONE,
    hint_bit_length_assign_negative_one,
);

const HINT_BIT_LENGTH_ASSIGN_2500: &str = "ids.bit_length = 2500";

fn hint_bit_length_assign_2500(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    write_value(
        "bit_length",
        MaybeRelocatable::Int(Felt252::from_hex_unchecked("0x9C4")),
        vm,
        hint_data,
    )?;

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_BIT_LENGTH_ASSIGN_2500: Hint =
    (HINT_BIT_LENGTH_ASSIGN_2500, hint_bit_length_assign_2500);

const HINT_PRINT_NS: &str = "print(\"N\", ids.N, \"n\", ids.n)";

fn hint_print_ns(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!(
        "N: {}, n: {}",
        get_value("N", vm, hint_data)?,
        get_value("n", vm, hint_data)?
    );
    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_PRINT_NS: Hint = (HINT_PRINT_NS, hint_print_ns);
