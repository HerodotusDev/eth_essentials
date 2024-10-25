const FELT_0: Felt252 = Felt252::ZERO;
const FELT_127: Felt252 = Felt252::from_hex_unchecked("0x7f");
const FELT_128: Felt252 = Felt252::from_hex_unchecked("0x80");
const FELT_183: Felt252 = Felt252::from_hex_unchecked("0xB7");
const FELT_184: Felt252 = Felt252::from_hex_unchecked("0xB8");
const FELT_191: Felt252 = Felt252::from_hex_unchecked("0xBF");
const FELT_192: Felt252 = Felt252::from_hex_unchecked("0xC0");
const FELT_247: Felt252 = Felt252::from_hex_unchecked("0xF7");
const FELT_248: Felt252 = Felt252::from_hex_unchecked("0xF8");
const FELT_255: Felt252 = Felt252::from_hex_unchecked("0xFF");

/// Check if the value indicates a single byte (0x00 to 0x7f).
fn is_single_byte(value: Felt252) -> bool {
    FELT_0 <= value && value <= FELT_127
}

/// Check if the value indicates a short string (0x80 to 0xb7).
fn is_short_string(value: Felt252) -> bool {
    FELT_128 <= value && value <= FELT_183
}

/// Check if the value indicates a long string (0xb8 to 0xbf).
fn is_long_string(value: Felt252) -> bool {
    FELT_184 <= value && value <= FELT_191
}

/// Check if the value indicates a short list (0xc0 to 0xf7).
fn is_short_list(value: Felt252) -> bool {
    FELT_192 <= value && value <= FELT_247
}

/// Check if the value indicates a long list (0xf8 to 0xff).
fn is_long_list(value: Felt252) -> bool {
    FELT_248 <= value && value <= FELT_255
}

use crate::hints::{Hint, HINTS};
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, insert_value_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_LONG_SHORT_LIST: &str = "from tools.py.hints import is_short_list, is_long_list\nif is_short_list(ids.list_prefix):\n    ids.long_short_list = 0\nelif is_long_list(ids.list_prefix):\n    ids.long_short_list = 1\nelse:\n    raise ValueError(f\"Invalid list prefix: {hex(ids.list_prefix)}. Not a recognized list type.\")";

fn hint_long_short_list(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let list_prefix = get_integer_from_var_name(
        "list_prefix",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    match list_prefix {
        value if is_short_list(value) => insert_value_from_var_name(
            "long_short_list",
            MaybeRelocatable::Int(Felt252::ZERO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value if is_long_list(value) => insert_value_from_var_name(
            "long_short_list",
            MaybeRelocatable::Int(Felt252::ONE),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value => Err(HintError::InvalidValue(Box::new((
            "Invalid list prefix. Not a recognized list type.",
            value,
            Felt252::ZERO,
        )))),
    }
}
#[distributed_slice(HINTS)]
static _HIT_LONG_SHORT_LIST: Hint = (HINT_LONG_SHORT_LIST, hint_long_short_list);

const HINT_FIRST_ITEM_TYPE: &str = "from tools.py.hints import is_single_byte, is_short_string\nif is_single_byte(ids.first_item_prefix):\n    ids.first_item_type = 0\nelif is_short_string(ids.first_item_prefix):\n    ids.first_item_type = 1\nelse:\n    raise ValueError(f\"Unsupported first item prefix: {hex(ids.first_item_prefix)}.\")";

fn hint_first_item_type(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let first_item_prefix = get_integer_from_var_name(
        "first_item_prefix",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    match first_item_prefix {
        value if is_single_byte(value) => insert_value_from_var_name(
            "first_item_type",
            MaybeRelocatable::Int(Felt252::ZERO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value if is_short_string(value) => insert_value_from_var_name(
            "first_item_type",
            MaybeRelocatable::Int(Felt252::ONE),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value => Err(HintError::InvalidValue(Box::new((
            "Unsupported first item prefix",
            value,
            Felt252::ZERO,
        )))),
    }
}

#[distributed_slice(HINTS)]
static _HINT_FIRST_ITEM_TYPE: Hint = (HINT_FIRST_ITEM_TYPE, hint_first_item_type);

const HINT_SECOND_ITEM_TYPE: &str = "from tools.py.hints import is_single_byte, is_short_string, is_long_string\nif is_single_byte(ids.second_item_prefix):\n    ids.second_item_type = 0\nelif is_short_string(ids.second_item_prefix):\n    ids.second_item_type = 1\nelif is_long_string(ids.second_item_prefix):\n    ids.second_item_type = 2\nelse:\n    raise ValueError(f\"Unsupported second item prefix: {hex(ids.second_item_prefix)}.\")";

fn hint_second_item_type(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let second_item_prefix = get_integer_from_var_name(
        "second_item_prefix",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    match second_item_prefix {
        value if is_single_byte(value) => insert_value_from_var_name(
            "second_item_type",
            MaybeRelocatable::Int(Felt252::ZERO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value if is_short_string(value) => insert_value_from_var_name(
            "second_item_type",
            MaybeRelocatable::Int(Felt252::ONE),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value if is_long_string(value) => insert_value_from_var_name(
            "second_item_type",
            MaybeRelocatable::Int(Felt252::TWO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value => Err(HintError::InvalidValue(Box::new((
            "Unsupported second item prefix",
            value,
            Felt252::ZERO,
        )))),
    }
}

#[distributed_slice(HINTS)]
static _HINT_SECOND_ITEM_TYPE: Hint = (HINT_SECOND_ITEM_TYPE, hint_second_item_type);

const HINT_ITEM_TYPE: &str = "from tools.py.hints import is_single_byte, is_short_string\nif is_single_byte(ids.item_prefix):\n    ids.item_type = 0\nelif is_short_string(ids.item_prefix):\n    ids.item_type = 1\nelse:\n    raise ValueError(f\"Unsupported item prefix: {hex(ids.item_prefix)} for a branch node. Should be single byte or short string only.\")";

fn hint_item_type(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let item_prefix = get_integer_from_var_name(
        "item_prefix",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    match item_prefix {
        value if is_single_byte(value) => insert_value_from_var_name(
            "item_type",
            MaybeRelocatable::Int(Felt252::ZERO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value if is_short_string(value) => insert_value_from_var_name(
            "item_type",
            MaybeRelocatable::Int(Felt252::ONE),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        ),
        value => Err(HintError::InvalidValue(Box::new((
            "Unsupported item prefix for a branch node. Should be single byte or short string only.",
            value,
            Felt252::ZERO,
        )))),
    }
}

#[distributed_slice(HINTS)]
static _HINT_ITEM_TYPE: Hint = (HINT_ITEM_TYPE, hint_item_type);
