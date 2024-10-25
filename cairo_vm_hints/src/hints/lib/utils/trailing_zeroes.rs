use crate::hints::{Hint, HINTS};
use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use std::collections::HashMap;

const HINT_TRAILING_ZEROES_BYTES: &str = "from tools.py.utils import count_trailing_zero_bytes_from_int\nids.trailing_zeroes_bytes = count_trailing_zero_bytes_from_int(ids.x)";

fn hint_trailing_zeroes_bytes(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x: Felt252 = utils::get_value("x", vm, hint_data)?;
    let reversed_hex = hex::encode(x.to_bytes_be())
        .bytes()
        .rev()
        .collect::<Vec<u8>>();

    let trailing_zeroes_bytes: usize = reversed_hex.into_iter().take_while(|c| *c == b'0').count();

    exec_scope.insert_value("trailing_zeroes_bytes", trailing_zeroes_bytes / 2);

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_TRAILING_ZEROES_BYTES: Hint = (HINT_TRAILING_ZEROES_BYTES, hint_trailing_zeroes_bytes);
