use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

mod construct_mmr;
mod dw_hack;
mod encode_packed_256;
mod mmr_size_generate;
mod print;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        construct_mmr::TEST_CONSTRUCT_MMR => construct_mmr::test_construct_mmr(vm, exec_scope, hint_data, constants),
        dw_hack::HINT_BIT_LENGTH_ASSIGN_140 => dw_hack::hint_bit_length_assign_140(vm, exec_scope, hint_data, constants),
        dw_hack::HINT_BIT_LENGTH_ASSIGN_NEGATIVE_ONE => dw_hack::hint_bit_length_assign_negative_one(vm, exec_scope, hint_data, constants),
        dw_hack::HINT_BIT_LENGTH_ASSIGN_2500 => dw_hack::hint_bit_length_assign_2500(vm, exec_scope, hint_data, constants),
        dw_hack::HINT_PRINT_NS => dw_hack::hint_print_ns(vm, exec_scope, hint_data, constants),
        encode_packed_256::HINT_GENERATE_TEST_VECTOR => encode_packed_256::hint_generate_test_vector(vm, exec_scope, hint_data, constants),
        mmr_size_generate::HINT_GENERATE_RANDOM => mmr_size_generate::hint_generate_random(vm, exec_scope, hint_data, constants),
        mmr_size_generate::HINT_GENERATE_SEQUENTIAL => mmr_size_generate::hint_generate_sequential(vm, exec_scope, hint_data, constants),
        print::HINT_PRINT_BREAKLINE => print::hint_print_breakline(vm, exec_scope, hint_data, constants),
        print::HINT_PRINT_PASS => print::hint_print_pass(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(hint_data.code.to_string().into_boxed_str())),
    }
}
