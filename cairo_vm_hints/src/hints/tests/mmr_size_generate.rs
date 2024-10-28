use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use rand::{thread_rng, Rng};
use starknet_types_core::felt::Felt;
use std::collections::{HashMap, HashSet};

use crate::utils::{get_value, write_vector};

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

pub const HINT_GENERATE_RANDOM: &str = "from tools.py.mmr import is_valid_mmr_size\nimport random\nprint(f\"Testing is_valid_mmr_size against python implementation with {ids.num_sizes} random sizes in [0, 20000000)...\")\nsizes_to_test = random.sample(range(0, 20000000), ids.num_sizes)\nexpected_output = [is_valid_mmr_size(size) for size in sizes_to_test]\nsegments.write_arg(ids.expected_output, expected_output)\nsegments.write_arg(ids.input_array, sizes_to_test)";

pub fn hint_generate_random(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let ids_data = &hint_data.ids_data;
    // let ap_tracking = &hint_data.ap_tracking;
    // let a = get_integer_from_var_name("x", vm, ids_data, ap_tracking)?;
    // vm.segments.write_arg(vm.seg, arg)
    let num_sizes: u64 = get_value("num_sizes", vm, hint_data)?.try_into().unwrap();

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

    write_vector("input_array", &input_array, vm, hint_data)?;
    write_vector("expected_output", &expected_output, vm, hint_data)?;

    Ok(())
}

pub const HINT_GENERATE_SEQUENTIAL: &str = "print(f\"Testing is_valid_mmr_size by creating the mmr for all sizes in [0, {ids.num_elems})...\")\nfrom tools.py.mmr import MMR\nmmr = MMR()\nvalid_mmr_sizes =set()\nfor i in range(ids.num_elems):\n    mmr.add(i)\n    valid_mmr_sizes.add(len(mmr.pos_hash))\n\nexpected_output = [size in valid_mmr_sizes for size in range(0, len(mmr.pos_hash) + 1)]\nsegments.write_arg(ids.expected_output, expected_output)\nsegments.write_arg(ids.input_array, list(range(0, len(mmr.pos_hash) + 1)))";

pub fn hint_generate_sequential(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let ids_data = &hint_data.ids_data;
    // let ap_tracking = &hint_data.ap_tracking;
    // let a = get_integer_from_var_name("x", vm, ids_data, ap_tracking)?;
    // vm.segments.write_arg(vm.seg, arg)
    let num_elems: u64 = get_value("num_elems", vm, hint_data)?.try_into().unwrap();

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

    write_vector("input_array", &input_array, vm, hint_data)?;
    write_vector("expected_output", &expected_output, vm, hint_data)?;

    Ok(())
}
