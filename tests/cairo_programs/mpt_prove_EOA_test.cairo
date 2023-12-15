%builtins output range_check bitwise keccak

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.registers import get_fp_and_pc

from src.libs.utils import (
    pow2alloc127,
    word_reverse_endian_64,
    uint256_add,
    felt_divmod_8,
    felt_divmod,
)
from src.libs.block_header import extract_state_root_little
from src.libs.rlp_little import (
    extract_byte_at_pos,
    get_0xff_mask,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    extract_nibble_from_key,
    pow_nibble,
    assert_subset_in_key,
)

const NODE_TYPE_LEAF = 1;
const NODE_TYPE_EXTENSION = 2;
const NODE_TYPE_BRANCH = 3;

// BLANK HASH BIG = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
// BLANK HASH LITTLE = 5094972239999916

func main{
    output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;
    local state_root_little: Uint256;
    let (account_proof: felt***) = alloc();
    local account_proof_len: felt;
    let (account_proof_bytes_len: felt*) = alloc();
    let (address_64_little: felt*) = alloc();
    %{
        from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async
        from tools.py.utils import bytes_to_8_bytes_chunks_little, split_128, reverse_endian_256, bytes_to_8_bytes_chunks
        from dotenv import load_dotenv
        import os
        from web3 import Web3
        from eth_utils import keccak
        import pickle
        load_dotenv()
        RPC_URL = os.getenv('RPC_URL_MAINNET')

        offline=True
        if not offline:
            w3 = Web3(Web3.HTTPProvider(RPC_URL))
            block = get_block_header(block_number)
            pickle.dump(block, open("block.pickle", "wb"))

        address = 0xd3cda913deb6f67967b99d67acdfa1712c293601
        block_number = 81326
        def get_block_header(number: int):
            blocks = fetch_blocks_from_rpc_no_async(number + 1, number - 1, RPC_URL)
            block = blocks[1]
            assert block.number == number, f"Block number mismatch {block.number} != {number}"
            return block

        block=pickle.load(open("block.pickle", "rb"))

        state_root = int(block.stateRoot.hex(),16)
        print(state_root.to_bytes(32, 'big'))
        state_root_little = split_128(int.from_bytes(state_root.to_bytes(32, 'big'), 'little'))
        ids.state_root_little.low = state_root_little[0]
        ids.state_root_little.high = state_root_little[1]

        if not offline:
            proof = w3.eth.get_proof(
                w3.toChecksumAddress(address),
                [0],
                block_number,
            )
            pickle.dump(proof, open("proof.pickle", "wb"))

        proof = pickle.load(open("proof.pickle", "rb"))

        assert keccak(proof['accountProof'][0]) == state_root.to_bytes(32, 'big')
        print(proof)
        print(f"state root", hex(state_root))
        print(keccak(proof['accountProof'][0]))
        accountProofbytes = [node for node in proof['accountProof']]
        assert keccak(accountProofbytes[0]) == state_root.to_bytes(32, 'big'), f"keccak mismatch {keccak(accountProofbytes[0])} != {state_root.to_bytes(32, 'big')}"
        accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
        accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]
        accountProof_big = [bytes_to_8_bytes_chunks(node) for node in accountProofbytes]
        print(accountProofbytes)
        print(accountProofbytes_len)
        print(accountProof)
        print(accountProof_big)
        segments.write_arg(ids.account_proof, accountProof)
        segments.write_arg(ids.account_proof_bytes_len, accountProofbytes_len)
        ids.account_proof_len = len(accountProof)
        segments.write_arg(ids.address_64_little, bytes_to_8_bytes_chunks_little(address.to_bytes(20, 'big')))

        def print_array(array_ptr, array_len):
            vals =[]
            for i in range(array_len):
                vals.append(memory[array_ptr + i])
            print([(hex(val), val.bit_length()) for val in vals])
    %}
    let (pow2_array: felt*) = pow2alloc127();

    let (key_little: Uint256) = keccak(address_64_little, 20);
    let (key_big: Uint256) = uint256_reverse_endian(key_little);
    %{ print(f"key_big : {hex(ids.key_big.low + 2**128*ids.key_big.high)}") %}
    verify_mpt_proof(
        mpt_proof=account_proof,
        mpt_proof_bytes_len=account_proof_bytes_len,
        mpt_proof_len=account_proof_len,
        key_little=key_little,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root_little,
        pow2_array=pow2_array,
    );

    return ();
}

// Verify a Merkle Patricia Tree proof.
// params:
// - mpt_proof: the proof to verify as an array of nodes, each node being an array of little endian 8 bytes chunks.
// - mpt_proof_bytes_len: array of the length in bytes of each node
// - mpt_proof_len: number of nodes in the proof
// - key_little: the key to verify as a little endian Uint256
// - key_nibble_index: the index of the next nibble of the key to verify (if a branch node is encountered)
// - accumulated_key: the key accumulated so far. Should start with Uint256(0, 0).
// - node_index: the index of the next node to verify
// - hash_to_assert: the current hash to assert for the current node. Should start with the root of the MPT.
// - pow2_array: array of powers of 2.
// returns:
// - the value of the proof as a felt* array of little endian 8 bytes chunks.
// - the total length in bytes of the value.
func verify_mpt_proof{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    mpt_proof: felt***,
    mpt_proof_bytes_len: felt*,
    mpt_proof_len: felt,
    key_little: Uint256,
    n_nibbles_already_checked: felt,
    node_index: felt,
    hash_to_assert: Uint256,
    pow2_array: felt*,
) -> (value: felt*, value_len: felt) {
    alloc_locals;
    if (node_index == mpt_proof_len - 1) {
        // Last node : item of interest is the value.
        // Check that the hash of the last node is the expected one.
        // Check that the final accumulated key is the expected one.
        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;

        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=1,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );
        // assert new_accumulated_key.low - key_little.low = 0;
        // assert new_accumulated_key.high - key_little.high = 0;

        return (item_of_interest, item_of_interest_len);
    } else {
        // Not last node : item of interest is the hash of the next node.
        // Check that the hash of the current node is the expected one.

        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        %{ print(f"node_hash : {hex(ids.node_hash.low + 2**128*ids.node_hash.high)}") %}
        %{ print(f"hash_to_assert : {hex(ids.hash_to_assert.low + 2**128*ids.hash_to_assert.high)}") %}
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;
        %{ print(f"\t Hash assert for node {ids.node_index} passed.") %}
        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=0,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );

        return verify_mpt_proof(
            mpt_proof=mpt_proof,
            mpt_proof_bytes_len=mpt_proof_bytes_len,
            mpt_proof_len=mpt_proof_len,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_checked,
            node_index=node_index + 1,
            hash_to_assert=[cast(item_of_interest, Uint256*)],
            pow2_array=pow2_array,
        );
    }
}

//
func decode_node_list_lazy{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    bytes_len: felt,
    pow2_array: felt*,
    last_node: felt,
    key_little: Uint256,
    n_nibbles_already_checked: felt,
) -> (n_nibbles_already_checked: felt, item_of_interest: felt*, item_of_interest_len: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let list_prefix = extract_byte_at_pos(rlp[0], 0, pow2_array);
    local long_short_list: felt;  // 0 for short, !=0 for long.
    %{
        if 0xc0 <= ids.list_prefix <= 0xf7:
            ids.long_short_list = 0
            print("List type : short")
        elif 0xf8 <= ids.list_prefix <= 0xff:
            ids.long_short_list = 1
            print("List type: long")
        else:
            print("Not a list.")
    %}
    local first_item_start_offset: felt;
    local list_len: felt;  // Bytes length of the list. (not including the prefix)

    if (long_short_list != 0) {
        // Long list.
        assert [range_check_ptr] = list_prefix - 0xf8;
        assert [range_check_ptr + 1] = 0xff - list_prefix;
        let len_len = list_prefix - 0xf7;
        assert first_item_start_offset = 1 + len_len;
        assert list_len = bytes_len - len_len - 1;
    } else {
        // Short list.
        assert [range_check_ptr] = list_prefix - 0xc0;
        assert [range_check_ptr + 1] = 0xf7 - list_prefix;
        assert first_item_start_offset = 1;
        assert list_len = list_prefix - 0xc0;
    }
    // At this point, if input is neither a long nor a short list, then the range check will fail.
    // %{ print("list_len", ids.list_len) %}
    // %{ print("first word", memory[ids.rlp]) %}
    assert [range_check_ptr + 2] = 7 - first_item_start_offset;
    // We now need to differentiate between the type of nodes: extension/leaf or branch.

    // %{ print("first item starts at byte", ids.first_item_start_offset) %}
    let first_item_prefix = extract_byte_at_pos(rlp[0], first_item_start_offset, pow2_array);

    // %{ print("First item prefix", hex(ids.first_item_prefix)) %}
    // Regardless of leaf, extension or branch, the first item should always be less than 32 bytes so a short string :
    // 0-55 bytes string long
    // (range [0x80, 0xb7] (dec. [128, 183])).
    assert [range_check_ptr + 3] = first_item_prefix - 0x80;
    assert [range_check_ptr + 4] = 0xb7 - first_item_prefix;
    tempvar range_check_ptr = range_check_ptr + 5;
    tempvar first_item_len = first_item_prefix - 0x80;
    tempvar second_item_starts_at_byte = first_item_start_offset + 1 + first_item_len;
    // %{ print("first item len:", ids.first_item_len, "bytes") %}
    // %{ print("second_item_starts_at_byte", ids.second_item_starts_at_byte) %}
    let (second_item_starts_at_word, second_item_start_offset) = felt_divmod(
        second_item_starts_at_byte, 8
    );
    // %{ print("second_item_starts_at_word", ids.second_item_starts_at_word) %}
    // %{ print("second_item_start_offset", ids.second_item_start_offset) %}
    // %{ print("second_item_first_word", memory[ids.rlp + ids.second_item_starts_at_word]) %}

    let second_item_prefix = extract_byte_at_pos(
        rlp[second_item_starts_at_word], second_item_start_offset, pow2_array
    );
    // %{ print("second_item_prefix", hex(ids.second_item_prefix)) %}
    local second_item_type: felt;
    %{
        if 0x00 <= ids.second_item_prefix <= 0x7f:
            ids.second_item_type = 0
            print(f"2nd item : single byte")
        elif 0x80 <= ids.second_item_prefix <= 0xb7:
            ids.second_item_type = 1
            print(f"2nd item : short string {ids.second_item_prefix - 0x80} bytes")
        elif 0xb8 <= ids.second_item_prefix <= 0xbf:
            ids.second_item_type = 2
            print(f"2nd item : long string (len_len {ids.second_item_prefix - 0xb7} bytes)")
        else:
            print(f"2nd item : unknown type {ids.second_item_prefix}")
    %}

    local second_item_bytes_len;
    local second_item_value_starts_at_byte;
    local third_item_starts_at_byte;
    local range_check_ptr_f;
    local bitwise_ptr_f: BitwiseBuiltin*;
    if (second_item_type == 0) {
        // Single byte.
        assert [range_check_ptr] = 0x7f - second_item_prefix;
        assert second_item_bytes_len = 1;
        assert second_item_value_starts_at_byte = second_item_starts_at_byte;
        assert third_item_starts_at_byte = second_item_starts_at_byte + second_item_bytes_len;
        assert range_check_ptr_f = range_check_ptr + 1;
        assert bitwise_ptr_f = bitwise_ptr;
    } else {
        if (second_item_type == 1) {
            // Short string.
            assert [range_check_ptr] = second_item_prefix - 0x80;
            assert [range_check_ptr + 1] = 0xb7 - second_item_prefix;
            assert second_item_bytes_len = second_item_prefix - 0x80;
            assert second_item_value_starts_at_byte = second_item_starts_at_byte + 1;
            assert third_item_starts_at_byte = second_item_starts_at_byte + 1 +
                second_item_bytes_len;
            assert range_check_ptr_f = range_check_ptr + 2;
            assert bitwise_ptr_f = bitwise_ptr;
        } else {
            // Long string.
            assert [range_check_ptr] = second_item_prefix - 0xb8;
            assert [range_check_ptr + 1] = 0xbf - second_item_prefix;

            tempvar len_len = second_item_prefix - 0xb7;
            assert second_item_value_starts_at_byte = second_item_starts_at_byte + 1 + len_len;
            tempvar end_of_len_virtual_offset = second_item_start_offset + 1 + len_len;

            local second_item_long_string_len_fits_into_current_word: felt;
            %{ ids.second_item_long_string_len_fits_into_current_word = (7 - ids.end_of_len_virtual_offset) >= 0 %}

            if (second_item_long_string_len_fits_into_current_word != 0) {
                // %{ print(f"Len len {ids.len_len} fits into current word.") %}
                // len_len bytes can be extracted from the current word.
                assert [range_check_ptr + 2] = 7 - end_of_len_virtual_offset;

                if (len_len == 1) {
                    // No need to reverse endian since it's a single byte.
                    let second_item_long_string_len = extract_byte_at_pos(
                        rlp[second_item_starts_at_word], second_item_start_offset + 1, pow2_array
                    );
                    assert second_item_bytes_len = second_item_long_string_len;
                    tempvar bitwise_ptr = bitwise_ptr;
                } else {
                    let second_item_long_string_len_little = extract_n_bytes_at_pos(
                        rlp[second_item_starts_at_word],
                        second_item_start_offset,
                        len_len,
                        pow2_array,
                    );
                    let (tmp) = word_reverse_endian_64(second_item_long_string_len_little);
                    assert second_item_bytes_len = tmp / pow2_array[64 - 8 * len_len];
                    tempvar bitwise_ptr = bitwise_ptr;
                }

                %{ print(f"second_item_long_string_len : {ids.second_item_bytes_len} bytes") %}
                assert third_item_starts_at_byte = second_item_starts_at_byte + 1 + len_len +
                    second_item_bytes_len;
                assert range_check_ptr_f = range_check_ptr + 3;
                assert bitwise_ptr_f = bitwise_ptr;
            } else {
                %{ print("Len len doesn't fit into current word.") %}
                // Very unlikely. But fix anyway.
                assert [range_check_ptr + 2] = end_of_len_virtual_offset - 8;
                assert range_check_ptr_f = range_check_ptr + 3;
                assert bitwise_ptr_f = bitwise_ptr;

                let n_bytes_to_extract_from_next_word = end_of_len_virtual_offset - 8;  // end_of_len_virtual_offset%8
                let n_bytes_to_extract_from_current_word = len_len -
                    n_bytes_to_extract_from_next_word;
                assert len_len = n_bytes_to_extract_from_next_word +
                    n_bytes_to_extract_from_current_word;
            }
        }
    }
    let range_check_ptr = range_check_ptr_f;
    let bitwise_ptr = bitwise_ptr_f;
    // %{ print(f"second_item_bytes_len : {ids.second_item_bytes_len} bytes") %}
    // %{ print(f"third item starts at byte {ids.third_item_starts_at_byte}") %}

    if (third_item_starts_at_byte == bytes_len) {
        // Node's list has only 2 items : it's a leaf or an extension.
        // Regardless, we need to decode the first item (key or key_end) and the second item (hash or value).
        // get the first item's prefix:
        // actual item value starts at byte first_item_start_offset + 1 (after the prefix)
        // Get the very first nibble.
        %{ print("Leaf/Extension case : two items") %}
        let first_item_prefix = extract_nibble_at_byte_pos(
            rlp[0], first_item_start_offset + 1, 0, pow2_array
        );
        %{
            prefix = ids.first_item_prefix
            if prefix == 0:
                print("First item is an extension node, even number of nibbles")
            elif prefix == 1:
                print("First item is an extension node, odd number of nibbles")
            elif prefix == 2:
                print("First item is a leaf node, even number of nibbles")
            elif prefix == 3:
                print("First item is a leaf node, odd number of nibbles")
            else:
                raise Exception(f"Unknown prefix {prefix} for MPT node with 2 items")
        %}
        local odd: felt;
        if (first_item_prefix == 0) {
            assert odd = 0;
        } else {
            if (first_item_prefix == 2) {
                assert odd = 0;
            } else {
                // 1 & 3 case.
                assert odd = 1;
            }
        }
        tempvar n_nibbles_in_first_item = 2 * first_item_len - odd;

        // Extract the key or key_end.
        let (local first_item_value_start_word, local first_item_value_start_offset) = felt_divmod(
            first_item_start_offset + 2 - odd, 8
        );
        let (
            extracted_key_subset, extracted_key_subset_len
        ) = extract_n_bytes_from_le_64_chunks_array(
            rlp,
            first_item_value_start_word,
            first_item_value_start_offset,
            first_item_len - 1,
            pow2_array,
        );
        %{
            print_array(ids.extracted_key_subset, ids.extracted_key_subset_len) 
            print(f"nibbles already checked: {ids.n_nibbles_already_checked}")
        %}
        assert_subset_in_key(
            key_subset=extracted_key_subset,
            key_subset_len=extracted_key_subset_len,
            key_subset_nibble_len=n_nibbles_in_first_item,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_already_checked,
            cut_nibble=odd,
            pow2_array=pow2_array,
        );

        // Extract the hash or value.

        if (last_node != 0) {
            // Extract value
            let (value_starts_word, value_start_offset) = felt_divmod(
                second_item_value_starts_at_byte, 8
            );
            let (value, value_len) = extract_n_bytes_from_le_64_chunks_array(
                rlp, value_starts_word, value_start_offset, second_item_bytes_len, pow2_array
            );
            return (
                n_nibbles_already_checked=n_nibbles_already_checked,
                item_of_interest=value,
                item_of_interest_len=value_len,
            );
        } else {
            // Extract hash (32 bytes)
            assert second_item_bytes_len = 32;
            let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                rlp, second_item_starts_at_word, second_item_start_offset, pow2_array
            );
            return (
                n_nibbles_already_checked=n_nibbles_already_checked,
                item_of_interest=cast(&hash_le, felt*),
                item_of_interest_len=2,
            );
        }
    } else {
        // Node has more than 2 items : it's a branch.
        if (last_node != 0) {
            %{ print(f"Branch case, last node : yes") %}

            // Branch is the last node in the proof. We need to extract the last item (17th).
            let (third_item_start_word, third_item_start_offset) = felt_divmod(
                third_item_starts_at_byte, 8
            );
            let (
                last_item_start_word, last_item_start_offset
            ) = jump_branch_node_till_element_at_index(
                rlp, 0, 16, third_item_start_word, third_item_start_offset, pow2_array
            );
            let (last_item: felt*, last_item_len: felt) = extract_n_bytes_from_le_64_chunks_array(
                rlp,
                last_item_start_word,
                last_item_start_offset,
                bytes_len - (last_item_start_word * 8 + last_item_start_offset),
                pow2_array,
            );

            return (n_nibbles_already_checked, last_item, last_item_len);
        } else {
            %{ print(f"Branch case, last node : no") %}
            // Branch is not the last node in the proof. We need to extract the hash corresponding to the next nibble of the key.

            // Get the next nibble of the key.
            let next_key_nibble = extract_nibble_from_key(
                key_little, n_nibbles_already_checked, pow2_array
            );
            %{ print(f"Next Key nibble {ids.next_key_nibble}") %}
            local item_of_interest_start_word: felt;
            local item_of_interest_start_offset: felt;
            local range_check_ptr_f;
            local bitwise_ptr_f: BitwiseBuiltin*;
            if (next_key_nibble == 0) {
                // Store coordinates of the first item's value.
                %{ print(f"\t Branch case, key index = 0") %}
                assert item_of_interest_start_word = 0;
                assert item_of_interest_start_offset = first_item_start_offset + 1;
                assert range_check_ptr_f = range_check_ptr;
                assert bitwise_ptr_f = bitwise_ptr;
            } else {
                if (next_key_nibble == 1) {
                    // Store coordinates of the second item's value.
                    %{ print(f"\t Branch case, key index = 1") %}
                    let (
                        second_item_value_start_word, second_item_value_start_offset
                    ) = felt_divmod_8(second_item_value_starts_at_byte + 1);
                    assert item_of_interest_start_word = second_item_value_start_word;
                    assert item_of_interest_start_offset = second_item_value_start_offset;
                    assert range_check_ptr_f = range_check_ptr;
                    assert bitwise_ptr_f = bitwise_ptr;
                } else {
                    if (next_key_nibble == 2) {
                        // Store coordinates of the third item's value.
                        %{ print(f"\t Branch case, key index = 2") %}
                        let (
                            third_item_value_start_word, third_item_value_start_offset
                        ) = felt_divmod_8(third_item_starts_at_byte + 1);
                        assert item_of_interest_start_word = third_item_value_start_word;
                        assert item_of_interest_start_offset = third_item_value_start_offset;
                        assert range_check_ptr_f = range_check_ptr;
                        assert bitwise_ptr_f = bitwise_ptr;
                    } else {
                        // Store coordinates of the item's value at index next_key_nibble != (0, 1, 2).
                        %{ print(f"\t Branch case, key index {ids.next_key_nibble}") %}
                        let (third_item_start_word, third_item_start_offset) = felt_divmod(
                            third_item_starts_at_byte, 8
                        );
                        let (
                            item_start_word, item_start_offset
                        ) = jump_branch_node_till_element_at_index(
                            rlp=rlp,
                            item_start_index=2,
                            target_index=next_key_nibble,
                            prefix_start_word=third_item_start_word,
                            prefix_start_offset=third_item_start_offset,
                            pow2_array=pow2_array,
                        );
                        let (item_value_start_word, item_value_start_offset) = felt_divmod(
                            item_start_word * 8 + item_start_offset + 1, 8
                        );
                        assert item_of_interest_start_word = item_value_start_word;
                        assert item_of_interest_start_offset = item_value_start_offset;
                        assert range_check_ptr_f = range_check_ptr;
                        assert bitwise_ptr_f = bitwise_ptr;
                    }
                }
            }
            let range_check_ptr = range_check_ptr_f;
            let bitwise_ptr = bitwise_ptr_f;
            // Extract the hash at the correct coordinates.

            let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                rlp, item_of_interest_start_word, item_of_interest_start_offset, pow2_array
            );
            // let nibble_pow = pow_nibble(next_key_nibble, 4 * n_nibbles_already_checked, pow2_array);
            // let (new_accumulated_key: Uint256, _) = uint256_add(accumulated_key, nibble_pow);

            // Return the Uint256 hash as a felt* of length 2.
            return (n_nibbles_already_checked + 1, cast(&hash_le, felt*), 2);
        }
    }
}

// Jumps on a branch until index i is reached.
// params:
// - rlp: the branch node as an array of little endian 8 bytes chunks.
// - item_start_index: the index of the  item to jump from.
// - target_index: the index of the item to jump to.
// - prefix_start_word: the word of the prefix to jump from. (Must correspond to item_start_index)
// - prefix_start_offset: the offset of the prefix to jump from. (Must correspond to item_start_index)
// - pow2_array: array of powers of 2.
// returns:
// - the word number of the item to jump to.
// - the offset of the item to jump to.
func jump_branch_node_till_element_at_index{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    item_start_index: felt,
    target_index: felt,
    prefix_start_word: felt,
    prefix_start_offset: felt,
    pow2_array: felt*,
) -> (start_word: felt, start_offset: felt) {
    alloc_locals;

    if (item_start_index == target_index) {
        return (prefix_start_word, prefix_start_offset);
    }

    let item_prefix = extract_byte_at_pos(rlp[prefix_start_word], prefix_start_offset, pow2_array);
    local item_type: felt;
    %{
        if 0x00 <= ids.item_prefix <= 0x7f:
            ids.item_type = 0
            #print(f"item : single byte")
        elif 0x80 <= ids.item_prefix <= 0xb7:
            ids.item_type = 1
            #print(f"item : short string at item {ids.item_start_index} {ids.item_prefix - 0x80} bytes")
        else:
            print(f"item : unknown type {ids.item_prefix} for a branch node. Should be single byte or short string only.")
    %}

    if (item_type == 0) {
        // Single byte. We need to go further by one byte.
        assert [range_check_ptr] = 0x7f - item_prefix;
        tempvar range_check_ptr = range_check_ptr + 1;
        if (prefix_start_offset + 1 == 8) {
            // We need to jump to the next word.
            return jump_branch_node_till_element_at_index(
                rlp, item_start_index + 1, target_index, prefix_start_word + 1, 0, pow2_array
            );
        } else {
            return jump_branch_node_till_element_at_index(
                rlp,
                item_start_index + 1,
                target_index,
                prefix_start_word,
                prefix_start_offset + 1,
                pow2_array,
            );
        }
    } else {
        // Short string.
        assert [range_check_ptr] = item_prefix - 0x80;
        assert [range_check_ptr + 1] = 0xb7 - item_prefix;
        tempvar range_check_ptr = range_check_ptr + 2;
        tempvar short_string_bytes_len = item_prefix - 0x80;
        let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
            prefix_start_word * 8 + prefix_start_offset + 1 + short_string_bytes_len
        );
        return jump_branch_node_till_element_at_index(
            rlp,
            item_start_index + 1,
            target_index,
            next_item_start_word,
            next_item_start_offset,
            pow2_array,
        );
    }
}
