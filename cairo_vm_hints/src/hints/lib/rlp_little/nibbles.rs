use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::insert_value_into_ap;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::cmp::Ordering;
use std::collections::HashMap;

const FELT_31: Felt252 = Felt252::from_hex_unchecked("0x1F");
const FELT_32: Felt252 = Felt252::from_hex_unchecked("0x20");
const FELT_63: Felt252 = Felt252::from_hex_unchecked("0x3F");

pub const HINT_IS_ZERO: &str = "ids.is_zero = 1 if ids.nibble_index <= (ids.key_leading_zeroes_nibbles - 1) else 0";

pub fn hint_is_zero(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let nibble_index: i128 = utils::get_value("nibble_index", vm, hint_data)?.try_into().unwrap();
    let key_leading_zeroes_nibbles: i128 = utils::get_value("key_leading_zeroes_nibbles", vm, hint_data)?.try_into().unwrap();
    utils::write_value(
        "is_zero",
        match nibble_index.cmp(&(key_leading_zeroes_nibbles - 1)) {
            Ordering::Less | Ordering::Equal => Felt252::ONE,
            Ordering::Greater => Felt252::ZERO,
        },
        vm,
        hint_data,
    )
}

pub const HINT_NIBBLE_FROM_LOW: &str =
    "ids.get_nibble_from_low = 1 if (0 <= ids.nibble_index <= 31 and ids.key_nibbles <= 32) or (32 <= ids.nibble_index <= 63 and ids.key_nibbles > 32) else 0";

pub fn hint_nibble_from_low(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let nibble_index: Felt252 = utils::get_value("nibble_index", vm, hint_data)?;
    let key_nibbles: Felt252 = utils::get_value("key_nibbles", vm, hint_data)?;

    let get_nibble_from_low = if (Felt252::ZERO <= nibble_index && nibble_index <= FELT_31 && key_nibbles <= FELT_32)
        || (FELT_32 <= nibble_index && nibble_index <= FELT_63 && key_nibbles > FELT_32)
    {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    utils::write_value("get_nibble_from_low", get_nibble_from_low, vm, hint_data)
}

pub const HINT_NEEDS_NEXT_WORD: &str = "ids.needs_next_word = 1 if ids.n_bytes > ids.avl_bytes_in_word else 0";

pub fn hint_needs_next_word(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let n_bytes: Felt252 = utils::get_value("n_bytes", vm, hint_data)?;
    let avl_bytes_in_word: Felt252 = utils::get_value("avl_bytes_in_word", vm, hint_data)?;

    let needs_next_word = if n_bytes > avl_bytes_in_word { Felt252::ONE } else { Felt252::ZERO };

    utils::write_value("needs_next_word", needs_next_word, vm, hint_data)
}

pub const HINT_NEEDS_NEXT_WORD_ENDING: &str = "ids.needs_next_word = 1 if ids.n_ending_bytes > ids.avl_bytes_in_word else 0";

pub fn hint_needs_next_word_ending(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let n_ending_bytes: Felt252 = utils::get_value("n_ending_bytes", vm, hint_data)?;
    let avl_bytes_in_word: Felt252 = utils::get_value("avl_bytes_in_word", vm, hint_data)?;

    let needs_next_word = if n_ending_bytes > avl_bytes_in_word {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    utils::write_value("needs_next_word", needs_next_word, vm, hint_data)
}

pub const HINT_WORDS_LOOP: &str = "memory[ap] = 1 if (ids.n_words_to_handle_in_loop - ids.n_words_handled) == 0 else 0";

pub fn hint_words_loop(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let n_words_to_handle_in_loop: Felt252 = utils::get_value("n_words_to_handle_in_loop", vm, hint_data)?;
    let n_words_handled: Felt252 = utils::get_value("n_words_handled", vm, hint_data)?;
    insert_value_into_ap(
        vm,
        if n_words_to_handle_in_loop == n_words_handled {
            Felt252::ONE
        } else {
            Felt252::ZERO
        },
    )
}
