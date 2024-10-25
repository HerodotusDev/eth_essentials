use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use linkme::distributed_slice;
use std::collections::HashMap;

mod lib;
mod tests;

type Hint = (
    &'static str,
    fn(
        vm: &mut VirtualMachine,
        exec_scope: &mut ExecutionScopes,
        hint_data: &HintProcessorData,
        constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError>,
);

#[distributed_slice]
pub static HINTS: [Hint];

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    for (hint_str, hint_func) in HINTS {
        if hint_data.code == hint_str.to_string() {
            return hint_func(vm, exec_scope, hint_data, constants);
        }
    }
    Err(HintError::UnknownHint(hint_data.code.as_str().into()))
}
