use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::HashMap;

pub const HINT_PRINT_BREAKLINE: &str = "print('\\n')";

pub fn hint_print_breakline(
    _vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("\n");
    Ok(())
}

pub const HINT_PRINT_PASS: &str = "print(f\"\\tPass!\\n\\n\")";

pub fn hint_print_pass(
    _vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("\tPass!\n\n");
    Ok(())
}
