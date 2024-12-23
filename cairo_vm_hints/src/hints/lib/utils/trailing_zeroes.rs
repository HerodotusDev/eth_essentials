use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::insert_value_from_var_name;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::HashMap;

pub const HINT_TRAILING_ZEROES_BYTES: &str =
    "from tools.py.utils import count_trailing_zero_bytes_from_int\nids.trailing_zeroes_bytes = count_trailing_zero_bytes_from_int(ids.x)";

pub fn hint_trailing_zeroes_bytes(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x: Felt252 = utils::get_value("x", vm, hint_data)?;
    insert_value_from_var_name(
        "trailing_zeroes_bytes",
        x.to_bytes_be().into_iter().rev().take_while(|c| *c == 0_u8).count(),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
