use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::get_relocatable_from_var_name;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::HashMap;

pub const HINT_EXPECTED_LEADING_ZEROES: &str = "from tools.py.utils import parse_int_to_bytes, count_leading_zero_nibbles_from_hex\nreversed_hex = parse_int_to_bytes(ids.x.low + (2 ** 128) * ids.x.high)[::-1].hex()\nexpected_leading_zeroes = count_leading_zero_nibbles_from_hex(reversed_hex[1:] if ids.cut_nibble == 1 else reversed_hex)";

pub fn hint_expected_leading_zeroes(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x_ptr = get_relocatable_from_var_name("x", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let x_felts = vm
        .get_continuous_range(x_ptr, 2)?
        .into_iter()
        .map(|v| v.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let x_low: u128  = x_felts[0].try_into().unwrap();
    let x_high: u128 = x_felts[1].try_into().unwrap();

    let mut le_bytes = [0u8; 32];
    le_bytes[..16].copy_from_slice(&x_low.to_le_bytes());
    le_bytes[16..].copy_from_slice(&x_high.to_le_bytes());

    let mut hex_str = hex::encode(le_bytes).trim_start_matches('0').to_string();
    if hex_str.is_empty() {
        hex_str.push('0');
    }
    if hex_str.len() & 1 == 1 {
        hex_str.insert(0, '0');
    }

    let cut_nibble: Felt252 = utils::get_value("cut_nibble", vm, hint_data)?;
    let hex_to_check = if cut_nibble == Felt252::ONE {
        hex_str.chars().skip(1).collect::<String>()
    } else {
        hex_str
    };

    let leading_zeroes: Felt252 = hex_to_check
        .chars()
        .take_while(|c| *c == '0')
        .count()
        .into();

    exec_scope.insert_value("expected_leading_zeroes", leading_zeroes);
    Ok(())
}

pub const HINT_EXPECTED_NIBBLE: &str = "key_hex = ids.key_leading_zeroes_nibbles * '0' + hex(ids.key.low + (2 ** 128) * ids.key.high)[2:]\nexpected_nibble = int(key_hex[ids.nibble_index + ids.key_leading_zeroes_nibbles], 16)";

pub fn hint_expected_nibble(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let key_ptr = get_relocatable_from_var_name("key", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let key = vm
        .get_continuous_range(key_ptr, 2)?
        .into_iter()
        .map(|v| v.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let key_low: u128 = key[0].try_into().unwrap();
    let key_high: u128 = key[1].try_into().unwrap();

    let key_leading_zeroes_nibbles: usize = utils::get_value("key_leading_zeroes_nibbles", vm, hint_data)?.try_into().unwrap();
    let nibble_index: usize = utils::get_value("nibble_index", vm, hint_data)?.try_into().unwrap();

    let hex = hex::encode([key_high.to_be_bytes(), key_low.to_be_bytes()].concat())
        .trim_start_matches('0')
        .to_string();
    let nibble_char = format!("{:0width$}{}", "", hex, width = key_leading_zeroes_nibbles)
        .chars()
        .nth(nibble_index + key_leading_zeroes_nibbles)
        .unwrap();

    exec_scope.insert_value("expected_nibble", nibble_char.to_digit(16).unwrap());

    Ok(())
}
