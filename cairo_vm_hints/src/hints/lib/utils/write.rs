use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use crate::utils;

pub const HINT_WRITE_2: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 2, memory, ap)";

pub fn hint_write_2(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(2).rev().enumerate() {
        println!("2 {}", byte);
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

pub const HINT_WRITE_3: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 3, memory, ap)";

pub fn hint_write_3(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(3).rev().enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

pub const HINT_WRITE_4: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 4, memory, ap)";

pub fn hint_write_4(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(4).rev().enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

pub const HINT_WRITE_5: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 5, memory, ap)";

pub fn hint_write_5(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(5).rev().enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

pub const HINT_WRITE_6: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 6, memory, ap)";

pub fn hint_write_6(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(6).rev().enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}

pub const HINT_WRITE_7: &str = "from tools.py.hints import write_word_to_memory\nwrite_word_to_memory(ids.word, 7, memory, ap)";

pub fn hint_write_7(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let word: Felt252 = utils::get_value("word", vm, hint_data)?;
    let ap = vm.get_ap();
    for (idx, byte) in word.to_bytes_be().into_iter().rev().take(7).rev().enumerate() {
        vm.insert_value((ap + idx)?, MaybeRelocatable::Int(byte.into()))
            .map_err(HintError::Memory)?;
    }

    Ok(())
}
