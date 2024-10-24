use crate::utils;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::Relocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use starknet_types_core::felt::NonZeroFelt;
use std::collections::HashMap;

pub const HINT_POW_CUT: &str =
    "ids.q, ids.r = divmod(memory[ids.array + ids.start_word + ids.i], ids.pow_cut)";

pub fn hint_pow_cut(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let array: usize = utils::get_value("array", vm, hint_data)?
        .try_into()
        .unwrap();
    let start_word: usize = utils::get_value("start_word", vm, hint_data)?
        .try_into()
        .unwrap();
    let i: usize = utils::get_value("i", vm, hint_data)?.try_into().unwrap();
    let pow_cut: Felt252 = utils::get_value("pow_cut", vm, hint_data)?;

    let value: Felt252 = *vm.get_integer(Relocatable {
        segment_index: isize::default(),
        offset: array + start_word + i,
    })?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(pow_cut).unwrap());
    utils::write_value("q", q, vm, hint_data)?;
    utils::write_value("r", r, vm, hint_data)
}
