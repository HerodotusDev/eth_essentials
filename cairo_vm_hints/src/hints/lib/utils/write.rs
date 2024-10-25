use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_WRITE_2: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 2, memory, ap)";

fn hint_write_2(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(2).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_2: Hint = (HINT_WRITE_2, hint_write_2);

const HINT_WRITE_3: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 3, memory, ap)";

fn hint_write_3(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(3).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_3: Hint = (HINT_WRITE_3, hint_write_3);

const HINT_WRITE_4: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 4, memory, ap)";

fn hint_write_4(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(4).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_4: Hint = (HINT_WRITE_4, hint_write_4);

const HINT_WRITE_5: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 5, memory, ap)";

fn hint_write_5(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(5).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_5: Hint = (HINT_WRITE_5, hint_write_5);

const HINT_WRITE_6: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 6, memory, ap)";

fn hint_write_6(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(6).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_6: Hint = (HINT_WRITE_6, hint_write_6);

const HINT_WRITE_7: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 7, memory, ap)";

fn hint_write_7(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().take(7).enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_WRITE_7: Hint = (HINT_WRITE_7, hint_write_7);
