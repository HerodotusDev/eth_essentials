use crate::hints::{Hint, HINTS};
use crate::mmr::{Keccak, Mmr, Poseidon};
use crate::utils::{split_u256, write_struct, write_value, write_vector};
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use linkme::distributed_slice;
use num_bigint::{BigUint, RandBigInt};
use num_traits::{Num, One};
use rand::{thread_rng, Rng};
use std::collections::HashMap;

const TEST_CONSTRUCT_MMR: &str = "import random
from tools.py.mmr import get_peaks, MMR, PoseidonHasher, KeccakHasher
STARK_PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481

def split_128(a):
    \"\"\"Takes in value, returns uint256-ish tuple.\"\"\"
    return [a & ((1 << 128) - 1), a >> 128]
def from_uint256(a):
    \"\"\"Takes in uint256-ish tuple, returns value.\"\"\"
    return a[0] + (a[1] << 128)
def write_uint256_array(ptr, array):
    counter = 0
    for uint in array:
        memory[ptr._reference_value+counter] = uint[0]
        memory[ptr._reference_value+counter+1] = uint[1]
        counter += 2

previous_n_values= random.randint(1, 200)
n_values_to_append=random.randint(1, 200)
ids.n_values_to_append=n_values_to_append;

# Initialize random values to be appended to the new MMR.
poseidon_hash_array = [random.randint(0, STARK_PRIME-1) for _ in range(n_values_to_append)]
keccak_hash_array = [split_128(random.randint(0, 2**256-1)) for _ in range(n_values_to_append)]
segments.write_arg(ids.poseidon_hash_array, poseidon_hash_array)
write_uint256_array(ids.keccak_hash_array, keccak_hash_array)


# Initialize MMR objects
mmr_poseidon = MMR(PoseidonHasher())
mmr_keccak = MMR(KeccakHasher())

# Initialize previous values
previous_values_poseidon = [random.randint(0, STARK_PRIME-1) for _ in range(previous_n_values)]
previous_values_keccak = [random.randint(0, 2**256-1) for _ in range(previous_n_values)]

# Fill MMRs with previous values
for elem in previous_values_poseidon:
   _= mmr_poseidon.add(elem)
for elem in previous_values_keccak:
   _= mmr_keccak.add(elem)

# Write the previous MMR size to the Cairo memory.
ids.mmr_offset=len(mmr_poseidon.pos_hash)

# Get the previous peaks and write them to the Cairo memory.
previous_peaks_poseidon = [mmr_poseidon.pos_hash[peak_position] for peak_position in get_peaks(len(mmr_poseidon.pos_hash))]
previous_peaks_keccak = [split_128(mmr_keccak.pos_hash[peak_position]) for peak_position in get_peaks(len(mmr_keccak.pos_hash))]
segments.write_arg(ids.previous_peaks_values_poseidon, previous_peaks_poseidon)
write_uint256_array(ids.previous_peaks_values_keccak, previous_peaks_keccak)

# Write the previous MMR root to the Cairo memory.
ids.mmr_last_root_poseidon = mmr_poseidon.get_root()
ids.mmr_last_root_keccak.low, ids.mmr_last_root_keccak.high = split_128(mmr_keccak.get_root())

# Fill MMRs with new values, in reversed order to match the Cairo code. (construct_mmr() appends the values starting from the last index of the array)
for new_elem in reversed(poseidon_hash_array):
    _= mmr_poseidon.add(new_elem)
for new_elem in reversed(keccak_hash_array):
    _= mmr_keccak.add(from_uint256(new_elem))

# Write the expected new MMR roots and length to the Cairo memory.
ids.expected_new_root_poseidon = mmr_poseidon.get_root()
ids.expected_new_root_keccak.low, ids.expected_new_root_keccak.high = split_128(mmr_keccak.get_root())
ids.expected_new_len = len(mmr_poseidon.pos_hash)";

fn test_construct_mmr(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let stark_prime = BigUint::from_str_radix(
        "3618502788666131213697322783095070105623107215331596699973092056135872020481",
        10,
    )
    .unwrap();
    let two_pow_256 = BigUint::from_str_radix(
        "115792089237316195423570985008687907853269984665640564039457584007913129639936",
        10,
    )
    .unwrap();

    let mut rng = thread_rng();

    let previous_n_values = rng.gen_range(1..=200);
    let n_values_to_append = rng.gen_range(1..=200);
    write_value("n_values_to_append", n_values_to_append, vm, hint_data)?;

    let poseidon_hash_array = (0..n_values_to_append)
        .map(|_| rng.gen_biguint_range(&BigUint::one(), &stark_prime))
        .collect::<Vec<_>>();
    let keccak_hash_array = (0..n_values_to_append)
        .map(|_| rng.gen_biguint_range(&BigUint::one(), &two_pow_256))
        .collect::<Vec<_>>();

    write_vector(
        "poseidon_hash_array",
        &poseidon_hash_array
            .iter()
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;
    write_vector(
        "keccak_hash_array",
        &keccak_hash_array
            .iter()
            .flat_map(split_u256)
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;

    let mut mmr_poseidon = Mmr::<Poseidon>::new();
    let mut mmr_keccak = Mmr::<Keccak>::new();

    (0..previous_n_values)
        .map(|_| rng.gen_biguint_range(&BigUint::one(), &stark_prime))
        .for_each(|x| mmr_poseidon.append(x));

    (0..previous_n_values)
        .map(|_| rng.gen_biguint_range(&BigUint::one(), &two_pow_256))
        .for_each(|x| mmr_keccak.append(x));

    write_value("mmr_offset", mmr_poseidon.size(), vm, hint_data)?;

    let previous_peaks_poseidon = mmr_poseidon.retrieve_nodes(mmr_poseidon.get_peaks());
    let previous_peaks_keccak = mmr_keccak.retrieve_nodes(mmr_keccak.get_peaks());

    write_vector(
        "previous_peaks_values_poseidon",
        &previous_peaks_poseidon
            .iter()
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;
    write_vector(
        "previous_peaks_values_keccak",
        &previous_peaks_keccak
            .iter()
            .flat_map(split_u256)
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;
    write_value(
        "mmr_last_root_poseidon",
        MaybeRelocatable::Int(mmr_poseidon.get_root().into()),
        vm,
        hint_data,
    )?;
    write_struct(
        "mmr_last_root_keccak",
        &split_u256(&mmr_keccak.get_root())
            .iter()
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;

    for elem in poseidon_hash_array.iter().rev() {
        mmr_poseidon.append(elem.clone());
    }
    for elem in keccak_hash_array.iter().rev() {
        mmr_keccak.append(elem.clone());
    }

    write_value(
        "expected_new_root_poseidon",
        MaybeRelocatable::Int(mmr_poseidon.get_root().into()),
        vm,
        hint_data,
    )?;
    write_struct(
        "expected_new_root_keccak",
        &split_u256(&mmr_keccak.get_root())
            .iter()
            .map(|x| MaybeRelocatable::Int(x.into()))
            .collect::<Vec<_>>(),
        vm,
        hint_data,
    )?;
    write_value("expected_new_len", mmr_keccak.size(), vm, hint_data)?;

    Ok(())
}

#[distributed_slice(HINTS)]
static _TEST_CONSTRUCT_MMR: Hint = (TEST_CONSTRUCT_MMR, test_construct_mmr);
