use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, get_ptr_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use rand::{thread_rng, Rng};
use starknet_types_core::felt::Felt;
use std::collections::HashMap;

fn is_valid_mmr_size(mut mmr_size: u64) -> bool {
    if mmr_size == 0 {
        return false;
    }
    let max_height = Felt::from(mmr_size).bits() as u32;
    for height in (0..=max_height).rev() {
        let node_count = 2u64.pow(height + 1) - 1;
        if node_count <= mmr_size {
            mmr_size -= node_count;
        }
    }
    mmr_size == 0
}

pub const TEST_IS_VALID_MMR_SIZE_GENERATE_RANDOM: &str = "from tools.py.mmr import is_valid_mmr_size
import random
print(f\"Testing is_valid_mmr_size against python implementation with {ids.num_sizes} random sizes in [0, 20000000)...\")
sizes_to_test = random.sample(range(0, 20000000), ids.num_sizes)
expected_output = [is_valid_mmr_size(size) for size in sizes_to_test]
segments.write_arg(ids.expected_output, expected_output)
segments.write_arg(ids.input_array, sizes_to_test)";

pub fn test_is_valid_mmr_size_generate_random(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let ids_data = &hint_data.ids_data;
    // let ap_tracking = &hint_data.ap_tracking;
    // let a = get_integer_from_var_name("x", vm, ids_data, ap_tracking)?;
    // vm.segments.write_arg(vm.seg, arg)
    let num_sizes: u64 =
        get_integer_from_var_name("num_sizes", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
            .try_into()
            .unwrap();

    println!(
        "Testing is_valid_mmr_size against python implementation with {} random sizes in [0, 20000000)...",
        num_sizes
    );

    let mut rng = thread_rng();
    let mut input_array = vec![];
    let mut expected_output = vec![];
    for _ in 0..num_sizes {
        let x = rng.gen_range(0..20000000);
        input_array.push(MaybeRelocatable::Int(x.into()));
        let y = is_valid_mmr_size(x);
        expected_output.push(MaybeRelocatable::Int(y.into()));
    }

    let expected_output_ptr = get_ptr_from_var_name(
        "expected_output",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let input_array_ptr = get_ptr_from_var_name(
        "input_array",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    vm.segments.load_data(input_array_ptr, &input_array)?;
    vm.segments
        .load_data(expected_output_ptr, &expected_output)?;

    Ok(())
}
