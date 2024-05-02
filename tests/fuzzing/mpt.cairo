%builtins output range_check bitwise keccak

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.registers import get_fp_and_pc

from lib.utils import pow2alloc128
from lib.mpt import verify_mpt_proof

func main{
    output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;
    local batch_len: felt;

    %{ ids.batch_len = len(program_input) %}

    let (pow2_array: felt*) = pow2alloc128();

    verify_n_mpt_proofs{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        pow2_array=pow2_array,
    }(batch_len, 0);

    return ();
}

func verify_n_mpt_proofs{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(batch_len: felt, index: felt) {
    alloc_locals;

    if (batch_len == index) {
        return ();
    }

    let (proof: felt**) = alloc();
    let (proof_bytes_len) = alloc();
    local proof_len: felt;
    local key: Uint256;
    local key_leading_zeroes: felt;
    local root: Uint256;

    %{
        from tools.py.utils import bytes_to_8_bytes_chunks_little, split_128, reverse_endian_256, count_leading_zero_nibbles_from_hex

        def encode_proof(proof):
            chunks = []
            bytes_len = []

            for node in proof:
                node_bytes = bytes.fromhex(node)
                bytes_len.append(len(node_bytes))
                chunks.append(bytes_to_8_bytes_chunks_little(node_bytes))

            return (chunks, bytes_len)


        batch = program_input[ids.index]
        (chunks, bytes_len) = encode_proof(batch["proof"])

        segments.write_arg(ids.proof, chunks)
        segments.write_arg(ids.proof_bytes_len, bytes_len)
        ids.proof_len = len(chunks)


        # handle root
        reversed_root = reverse_endian_256(int(batch["root"], 16))
        (root_low, root_high) = split_128(reversed_root)
        ids.root.low = root_low
        ids.root.high = root_high

        #handle key
        ids.key_leading_zeroes = count_leading_zero_nibbles_from_hex(batch["key"])
        (key_low, key_high) = split_128(int(batch["key"], 16))
        ids.key.low = key_low
        ids.key.high = key_high
    %}

    let (_, _) = verify_mpt_proof(
        mpt_proof=proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeroes,
        root=root,
        pow2_array=pow2_array,
    );

    return verify_n_mpt_proofs(batch_len, index + 1);
}
