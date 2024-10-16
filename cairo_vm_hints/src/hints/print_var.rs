use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::get_integer_from_var_name;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::HashMap;

pub const PRINT_VAR: &str = "print(ids.x)";

pub fn print_var(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let ids_data = &hint_data.ids_data;
    let ap_tracking = &hint_data.ap_tracking;
    let a = get_integer_from_var_name("x", vm, ids_data, ap_tracking)?;
    println!("printing {}", a);
    Ok(())
}
