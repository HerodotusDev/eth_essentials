use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

mod bit_length;
mod block_header;
mod mmr;
mod mpt;
mod rlp_little;
mod utils;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let hints = [
        bit_length::run_hint,
        block_header::run_hint,
        mmr::run_hint,
        mpt::run_hint,
        rlp_little::run_hint,
        utils::run_hint,
    ];

    for hint in hints.iter() {
        let res = hint(vm, exec_scope, hint_data, constants);
        if !matches!(res, Err(HintError::UnknownHint(_))) {
            return res;
        }
    }
    Err(HintError::UnknownHint(
        hint_data.code.to_string().into_boxed_str(),
    ))
}