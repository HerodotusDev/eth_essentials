use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_EXPECTED_LEADING_ZEROES: &str = "from tools.py.utils import parse_int_to_bytes, count_leading_zero_nibbles_from_hex\nreversed_hex = parse_int_to_bytes(ids.x.low + (2 ** 128) * ids.x.high)[::-1].hex()\nexpected_leading_zeroes = count_leading_zero_nibbles_from_hex(reversed_hex[1:] if ids.cut_nibble == 1 else reversed_hex)";

fn hint_expected_leading_zeroes(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x_low: u128 = utils::get_value("x.low", vm, hint_data)?
        .try_into()
        .unwrap();
    let x_high: u128 = utils::get_value("x.high", vm, hint_data)?
        .try_into()
        .unwrap();
    let cut_nibble = utils::get_value("cut_nibble", vm, hint_data)?;

    let reversed_hex = hex::encode([x_low.to_be_bytes(), x_high.to_be_bytes()].concat())
        .bytes()
        .rev()
        .collect::<Vec<u8>>();

    // Calculate expected leading zeroes, optionally skipping the first nibble
    let hex_to_check = if cut_nibble == Felt252::ONE {
        reversed_hex[1..].to_vec()
    } else {
        reversed_hex
    };
    let expected_leading_zeroes: Felt252 = hex_to_check
        .into_iter()
        .take_while(|c| *c == b'0')
        .count()
        .into();
    exec_scope.insert_value("expected_leading_zeroes", expected_leading_zeroes);

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_EXPECTED_LEADING_ZEROES: Hint =
    (HINT_EXPECTED_LEADING_ZEROES, hint_expected_leading_zeroes);

const HINT_EXPECTED_NIBBLE: &str = "key_hex = ids.key_leading_zeroes_nibbles * '0' + hex(ids.key.low + (2 ** 128) * ids.key.high)[2:]\nexpected_nibble = int(key_hex[ids.nibble_index + ids.key_leading_zeroes_nibbles], 16)";

fn hint_expected_nibble(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let key_low: u128 = utils::get_value("key.low", vm, hint_data)?
        .try_into()
        .unwrap();
    let key_high: u128 = utils::get_value("key.high", vm, hint_data)?
        .try_into()
        .unwrap();
    let key_leading_zeroes_nibbles: usize =
        utils::get_value("key_leading_zeroes_nibbles", vm, hint_data)?
            .try_into()
            .unwrap();
    let nibble_index: usize = utils::get_value("nibble_index", vm, hint_data)?
        .try_into()
        .unwrap();

    let hex = hex::encode([key_low.to_be_bytes(), key_high.to_be_bytes()].concat());
    let nibble_char = format!("{:0width$}{}", "", hex, width = key_leading_zeroes_nibbles)
        .chars()
        .nth(nibble_index + key_leading_zeroes_nibbles)
        .unwrap();
    exec_scope.insert_value("expected_nibble", nibble_char.to_digit(16).unwrap());

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_EXPECTED_NIBBLE: Hint = (HINT_EXPECTED_NIBBLE, hint_expected_nibble);
