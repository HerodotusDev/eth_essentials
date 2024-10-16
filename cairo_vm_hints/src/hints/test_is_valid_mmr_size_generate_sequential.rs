use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, get_ptr_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::collections::{HashMap, HashSet};

pub const TEST_IS_VALID_MMR_SIZE_GENERATE_SEQUENTIAL: &str = "print(f\"Testing is_valid_mmr_size by creating the mmr for all sizes in [0, {ids.num_elems})...\")
from tools.py.mmr import MMR
mmr = MMR()
valid_mmr_sizes = set()
for i in range(ids.num_elems):
    mmr.add(i)
    valid_mmr_sizes.add(len(mmr.pos_hash))

expected_output = [size in valid_mmr_sizes for size in range(0, len(mmr.pos_hash) + 1)]
for out, inp in zip(expected_output, range(0, len(mmr.pos_hash) + 1)):
    print(out, inp)
segments.write_arg(ids.expected_output, expected_output)
segments.write_arg(ids.input_array, list(range(0, len(mmr.pos_hash) + 1)))";

pub fn test_is_valid_mmr_size_generate_sequential(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let ids_data = &hint_data.ids_data;
    // let ap_tracking = &hint_data.ap_tracking;
    // let a = get_integer_from_var_name("x", vm, ids_data, ap_tracking)?;
    // vm.segments.write_arg(vm.seg, arg)
    let num_elems: u64 =
        get_integer_from_var_name("num_elems", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
            .try_into()
            .unwrap();

    println!(
        "Testing is_valid_mmr_size by creating the mmr for all sizes in [0, {})...",
        num_elems
    );

    let mut valid_mmr_sizes = HashSet::new();
    let mut mmr_size = 0;
    for leaf_count in 1..=num_elems {
        mmr_size = 2 * leaf_count - (leaf_count.count_ones() as u64);
        valid_mmr_sizes.insert(mmr_size);
    }
    let expected_output = (0..=mmr_size)
        .map(|i| MaybeRelocatable::Int(valid_mmr_sizes.contains(&i).into()))
        .collect::<Vec<_>>();
    let input_array = (0..=mmr_size)
        .map(|x| MaybeRelocatable::Int(x.into()))
        .collect::<Vec<_>>();

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
