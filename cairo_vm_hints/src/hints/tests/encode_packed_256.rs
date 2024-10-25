use crate::hints::{Hint, HINTS};
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use rand::Rng;
use sha3::Digest;
use sha3::Keccak256;
use std::collections::HashMap;

use crate::utils::{write_value, write_vector};

fn get_random() -> [u8; 32] {
    let mut rng = rand::thread_rng();
    let mut arr = [0u8; 32];
    rng.fill(&mut arr);
    arr
}

fn split_128(value: [u8; 32]) -> ([u8; 16], [u8; 16]) {
    let mut lower = [0u8; 16];
    let mut upper = [0u8; 16];

    lower.copy_from_slice(&value[0..16]);
    upper.copy_from_slice(&value[16..32]);

    (lower, upper)
}

fn keccak(x: &[u8; 32], y: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update(x);
    hasher.update(y);
    hasher.finalize().into()
}

const HINT_GENERATE_TEST_VECTOR: &str = "import sha3\nimport random\nfrom web3 import Web3\ndef split_128(a):\n    \"\"\"Takes in value, returns uint256-ish tuple.\"\"\"\n    return [a & ((1 << 128) - 1), a >> 128]\ndef write_uint256_array(ptr, array):\n    counter = 0\n    for uint in array:\n        memory[ptr._reference_value+counter] = uint[0]\n        memory[ptr._reference_value+counter+1] = uint[1]\n        counter += 2\ndef generate_n_bit_random(n):\n    return random.randint(2**(n-1), 2**n - 1)\n\n# Implementation of solitidy keccak256(encodedPacked(x, y)) in python.\ndef encode_packed_256_256(x_y):\n    return int(Web3.solidityKeccak([\"uint256\", \"uint256\"], [x_y[0], x_y[1]]).hex(), 16)\n# Another implementation that uses sha3 directly and should be equal. \ndef keccak_256_256(x_y):\n    k=sha3.keccak_256()\n    k.update(x_y[0].to_bytes(32, 'big'))\n    k.update(x_y[1].to_bytes(32, 'big'))\n    return int.from_bytes(k.digest(), 'big')\n\n# Build Test vector [[x_1, y_1], [x_2, y_2], ..., [x_len, y_len]].\n\n# 256 random pairs of numbers, each pair having two random numbers of 1-256 bits.\nx_y_list = [[generate_n_bit_random(random.randint(1, 256)), generate_n_bit_random(random.randint(1, 256))] for _ in range(256)]\n# Adds 256 more pairs of equal bit length to the test vector.\nx_y_list += [[generate_n_bit_random(i), generate_n_bit_random(i)] for i in range(1,257)]\n\nkeccak_output_list = [encode_packed_256_256(x_y) for x_y in x_y_list]\nkeccak_result_list = [keccak_256_256(x_y) for x_y in x_y_list]\n\n# Sanity check on keccak implementations.\nassert all([keccak_output_list[i] == keccak_result_list[i] for i in range(len(keccak_output_list))])\n\n\n# Prepare x_array and y_array :\nx_array_split = [split_128(x_y[0]) for x_y in x_y_list]\ny_array_split = [split_128(x_y[1]) for x_y in x_y_list]\n# Write x_array : \nwrite_uint256_array(ids.x_array, x_array_split)\n# Write y_array :\nwrite_uint256_array(ids.y_array, y_array_split)\n\n# Prepare keccak_result_array :\nkeccak_result_list_split = [split_128(keccak_result) for keccak_result in keccak_result_list]\n# Write keccak_result_array :\nwrite_uint256_array(ids.keccak_result_array, keccak_result_list_split)\n\n# Write len :\nids.len = len(keccak_result_list)";

fn hint_generate_test_vector(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let (x_list, y_list): (Vec<[u8; 32]>, Vec<[u8; 32]>) =
        (0..512).map(|_| (get_random(), get_random())).unzip();

    let keccak_result_list: Vec<[u8; 32]> = x_list
        .iter()
        .zip(y_list.iter())
        .map(|(x, y)| keccak(x, y))
        .collect();

    let x_array: Vec<MaybeRelocatable> = x_list
        .into_iter()
        .flat_map(|x| {
            let (xl, xh) = split_128(x);
            [
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xh)),
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xl)),
            ]
        })
        .collect();
    write_vector("x_array", &x_array, vm, hint_data)?;

    let y_array: Vec<MaybeRelocatable> = y_list
        .into_iter()
        .flat_map(|x| {
            let (xl, xh) = split_128(x);
            [
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xh)),
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xl)),
            ]
        })
        .collect();
    write_vector("y_array", &y_array, vm, hint_data)?;

    let keccak_result_array: Vec<MaybeRelocatable> = keccak_result_list
        .into_iter()
        .flat_map(|x| {
            let (xl, xh) = split_128(x);
            [
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xh)),
                MaybeRelocatable::Int(Felt252::from_bytes_be_slice(&xl)),
            ]
        })
        .collect();
    write_vector("keccak_result_array", &keccak_result_array, vm, hint_data)?;

    write_value(
        "len",
        MaybeRelocatable::Int(Felt252::from(keccak_result_array.len() / 2)),
        vm,
        hint_data,
    )?;

    Ok(())
}

#[distributed_slice(HINTS)]
static _HINT_GENERATE_TEST_VECTOR: Hint = (HINT_GENERATE_TEST_VECTOR, hint_generate_test_vector);
