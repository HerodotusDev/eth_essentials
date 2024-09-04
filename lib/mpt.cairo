from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    assert_subset_in_key_be,
    extract_nibble_from_key_be,
    n_nibbles_in_key,
)
from lib.utils import (
    felt_divmod,
    felt_divmod_8,
    word_reverse_endian_64,
    get_felt_bitlength_128,
    uint256_reverse_endian_no_padding,
    get_uint256_bit_length,
    n_bits_to_n_nibbles,
)

// Verify a Merkle Patricia Tree proof.
// params:
// - mpt_proof: the proof to verify as an array of nodes, each node being an array of little endian 8 bytes chunks.
// - mpt_proof_bytes_len: array of the length in bytes of each node
// - mpt_proof_len: number of nodes in the proof
// - key_be: the key to verify as a big endian Uint256 number.
// - key_be_leading_zeroes_nibbles: the number of leading zeroes nibbles in the key. If the key is 0x007, then 3.
// - root: the root of the MPT as a little endian Uint256 number.
// - pow2_array: array of powers of 2.
// returns:
// - the value of the proof as a felt* array of little endian 8 bytes chunks.
// - the total length in bytes of the value.
// If the proof passed is a non inclusion proof for the given key,
// returns (value=rlp, value_len=-1).
func verify_mpt_proof{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    mpt_proof: felt**,
    mpt_proof_bytes_len: felt*,
    mpt_proof_len: felt,
    key_be: Uint256,
    key_be_leading_zeroes_nibbles: felt,
    root: Uint256,
    pow2_array: felt*,
) -> (value: felt*, value_len: felt) {
    // %{ print(f"Veryfing key 0x{'0'*ids.key_be_leading_zeroes_nibbles}{hex(ids.key_be.low+2**128*ids.key_be.high)[2:]}") %}
    // Verify the key is a valid Uint256 number.
    assert [range_check_ptr] = key_be.low;
    assert [range_check_ptr + 1] = key_be.high;
    // Verify the number of leading zeroes nibbles in the key is valid.
    assert [range_check_ptr + 2] = key_be_leading_zeroes_nibbles;
    tempvar range_check_ptr = range_check_ptr + 3;
    // Count the number of nibbles in the key (excluding leading zeroes).
    let (num_nibbles_in_key_without_leading_zeroes) = n_nibbles_in_key(key_be, pow2_array);
    let num_nibbles_in_key = num_nibbles_in_key_without_leading_zeroes +
        key_be_leading_zeroes_nibbles;
    // %{ print(f"num_nibbles_in_key: {ids.num_nibbles_in_key}, key_be_leading_zeroes_nibbles: {ids.key_be_leading_zeroes_nibbles}") %}
    // Verify the total number of nibbles in the key is in the range [0, 64].
    assert [range_check_ptr] = 64 - num_nibbles_in_key;
    tempvar range_check_ptr = range_check_ptr + 1;

    return verify_mpt_proof_inner(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=mpt_proof_bytes_len,
        mpt_proof_len=mpt_proof_len,
        key_be=key_be,
        key_be_nibbles=num_nibbles_in_key_without_leading_zeroes,
        key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=root,
        pow2_array=pow2_array,
    );
}

// Inner function for verify_mpt_proof.
// Should not be called directly.
func verify_mpt_proof_inner{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}(
    mpt_proof: felt**,
    mpt_proof_bytes_len: felt*,
    mpt_proof_len: felt,
    key_be: Uint256,
    key_be_nibbles: felt,
    key_be_leading_zeroes_nibbles: felt,
    n_nibbles_already_checked: felt,
    node_index: felt,
    hash_to_assert: Uint256,
    pow2_array: felt*,
) -> (value: felt*, value_len: felt) {
    alloc_locals;
    // %{ print(f"\n\nNode index {ids.node_index+1}/{ids.mpt_proof_len} \n \t {ids.n_nibbles_already_checked=}") %}
    if (node_index == mpt_proof_len - 1) {
        // Last node : item of interest is the value.
        // Check that the hash of the last node is the expected one.
        // Check that the final accumulated key is the expected one.
        // Check the total number of nibbles in the key is equal to the number of nibbles checked in the key.
        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        // %{ print(f"node_hash : {hex(ids.node_hash.low + 2**128*ids.node_hash.high)}") %}
        // %{ print(f"hash_to_assert : {hex(ids.hash_to_assert.low + 2**128*ids.hash_to_assert.high)}") %}
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;

        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=1,
            key_be=key_be,
            key_be_nibbles=key_be_nibbles,
            key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );
        assert key_be_leading_zeroes_nibbles + key_be_nibbles = n_nibbles_checked;
        return (item_of_interest, item_of_interest_len);
    } else {
        // Not last node : item of interest is the hash of the next node.
        // Check that the hash of the current node is the expected one.

        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        // %{ print(f"node_hash : {hex(ids.node_hash.low + 2**128*ids.node_hash.high)}") %}
        // %{ print(f"hash_to_assert : {hex(ids.hash_to_assert.low + 2**128*ids.hash_to_assert.high)}") %}
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;
        // %{ print(f"\t Hash assert for node {ids.node_index} passed.") %}
        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=0,
            key_be=key_be,
            key_be_nibbles=key_be_nibbles,
            key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );

        return verify_mpt_proof_inner(
            mpt_proof=mpt_proof,
            mpt_proof_bytes_len=mpt_proof_bytes_len,
            mpt_proof_len=mpt_proof_len,
            key_be=key_be,
            key_be_nibbles=key_be_nibbles,
            key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
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
    key_be: Uint256,
    key_be_nibbles: felt,
    key_be_leading_zeroes_nibbles: felt,
    n_nibbles_already_checked: felt,
) -> (n_nibbles_already_checked: felt, item_of_interest: felt*, item_of_interest_len: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let list_prefix = extract_byte_at_pos(rlp[0], 0, pow2_array);
    local long_short_list: felt;  // 0 for short, !=0 for long.
    %{
        if 0xc0 <= ids.list_prefix <= 0xf7:
            ids.long_short_list = 0
            #print("List type : short")
        elif 0xf8 <= ids.list_prefix <= 0xff:
            ids.long_short_list = 1
            #print("List type: long")
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
    // Regardless of leaf, extension or branch, the first item should always be less than 32 bytes so a short string / single byte :
    // 0-55 bytes string long
    // (range [0x80, 0xb7] (dec. [128, 183])).

    local first_item_type;
    local first_item_len;
    local second_item_starts_at_byte;
    %{
        if 0 <= ids.first_item_prefix <= 0x7f:
            ids.first_item_type = 0 # Single byte
        elif 0x80 <= ids.first_item_prefix <= 0xb7:
            ids.first_item_type = 1 # Short string
        else:
            print(f"Unsupported first item type for prefix {ids.first_item_prefix=}")
    %}
    if (first_item_type != 0) {
        // Short string
        assert [range_check_ptr + 3] = first_item_prefix - 0x80;
        assert [range_check_ptr + 4] = 0xb7 - first_item_prefix;
        assert first_item_len = first_item_prefix - 0x80;
        assert second_item_starts_at_byte = first_item_start_offset + 1 + first_item_len;
        tempvar range_check_ptr = range_check_ptr + 5;
    } else {
        // Single byte
        // %{ print(f"First item is single byte, computing second item") %}
        assert [range_check_ptr + 3] = 0x7f - first_item_prefix;
        assert first_item_len = 1;
        assert second_item_starts_at_byte = first_item_start_offset + first_item_len;
        tempvar range_check_ptr = range_check_ptr + 4;
    }
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
            #print(f"2nd item : single byte")
        elif 0x80 <= ids.second_item_prefix <= 0xb7:
            ids.second_item_type = 1
            #print(f"2nd item : short string {ids.second_item_prefix - 0x80} bytes")
        elif 0xb8 <= ids.second_item_prefix <= 0xbf:
            ids.second_item_type = 2
            #print(f"2nd item : long string (len_len {ids.second_item_prefix - 0xb7} bytes)")
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
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar len_len = second_item_prefix - 0xb7;
            assert second_item_value_starts_at_byte = second_item_starts_at_byte + 1 + len_len;
            let (second_item_len_len_start_word, second_item_len_len_start_offset) = felt_divmod_8(
                second_item_starts_at_byte + 1
            );
            if (len_len == 1) {
                // No need to reverse endian since it's a single byte.
                let second_item_long_string_len = extract_byte_at_pos(
                    rlp[second_item_len_len_start_word],
                    second_item_len_len_start_offset,
                    pow2_array,
                );
                assert second_item_bytes_len = second_item_long_string_len;
                tempvar bitwise_ptr = bitwise_ptr;
                tempvar range_check_ptr = range_check_ptr;
            } else {
                let (
                    second_item_long_string_len_ptr, n_words
                ) = extract_n_bytes_from_le_64_chunks_array(
                    array=rlp,
                    start_word=second_item_len_len_start_word,
                    start_offset=second_item_len_len_start_offset,
                    n_bytes=len_len,
                    pow2_array=pow2_array,
                );
                assert n_words = 1;  // Extremely large size for long strings forbidden.

                let second_item_long_string_len = [second_item_long_string_len_ptr];
                let (tmp) = word_reverse_endian_64(second_item_long_string_len);
                assert second_item_bytes_len = tmp / pow2_array[64 - 8 * len_len];
                tempvar bitwise_ptr = bitwise_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }

            // %{ print(f"second_item_long_string_len : {ids.second_item_bytes_len} bytes") %}
            assert third_item_starts_at_byte = second_item_starts_at_byte + 1 + len_len +
                second_item_bytes_len;
            assert range_check_ptr_f = range_check_ptr;
            assert bitwise_ptr_f = bitwise_ptr;
        }
    }
    let range_check_ptr = range_check_ptr_f;
    let bitwise_ptr = bitwise_ptr_f;
    // %{ print(f"second_item_bytes_len : {ids.second_item_bytes_len} bytes") %}
    // %{ print(f"third item starts at byte {ids.third_item_starts_at_byte}") %}

    if (third_item_starts_at_byte == bytes_len) {
        // %{ print("two items => Leaf/Extension case") %}

        // Node's list has only 2 items : it's a leaf or an extension.
        // Regardless, we need to decode the first item (key or key_end) and the second item (hash or value).
        // actual item value starts at byte first_item_start_offset + 1 (after the prefix)
        // Get the very first nibble.

        // Ensure first_item_type is either 0 or 1.
        assert (first_item_type - 1) * (first_item_type) = 0;

        let first_item_key_prefix = extract_nibble_at_byte_pos(
            rlp[0], first_item_start_offset + first_item_type, 0, pow2_array
        );
        // %{
        //     prefix = ids.first_item_key_prefix
        //     if prefix == 0:
        //         print("First item is an extension node, even number of nibbles")
        //     elif prefix == 1:
        //         print("First item is an extension node, odd number of nibbles")
        //     elif prefix == 2:
        //         print("First item is a leaf node, even number of nibbles")
        //     elif prefix == 3:
        //         print("First item is a leaf node, odd number of nibbles")
        //     else:
        //         raise Exception(f"Unknown prefix {prefix} for MPT node with 2 items")
        // %}
        local odd: felt;
        if (first_item_key_prefix == 0) {
            assert odd = 0;
        } else {
            if (first_item_key_prefix == 2) {
                assert odd = 0;
            } else {
                // 1 & 3 case.
                assert odd = 1;
            }
        }

        local range_check_ptr_f;
        local bitwise_ptr_f: BitwiseBuiltin*;
        local n_nibbles_already_checked_f;
        local pow2_array_f: felt*;

        local key_checked: felt;
        if (first_item_type != 0) {
            // First item is a long string.
            tempvar n_nibbles_in_first_item = 2 * (first_item_len - 1) + odd;
            // %{ print(f"n_nibbles_in_first_item : {ids.n_nibbles_in_first_item}") %}
            // Extract the key or key_end. start offset + 1 (item prefix) + 1 (key prefix) - odd (1 if to include prefix's byte in case the nibbles are odd).
            let first_item_value_starts_at_byte = first_item_start_offset + 2 - odd;
            // %{ print(f"\t {ids.first_item_value_starts_at_byte=} \n\t {ids.first_item_start_offset=} \n\t {ids.first_item_type=} \n\t {ids.odd=} \n\t {ids.first_item_len=} \n\t {ids.first_item_type+ids.odd=} \n\t {ids.first_item_start_offset+ids.first_item_type+1-ids.odd=}") %}
            let (
                local first_item_value_start_word, local first_item_value_start_offset
            ) = felt_divmod(first_item_value_starts_at_byte, 8);
            let n_bytes_to_extract = first_item_len - 1 + odd;  // - first_item_type + odd;
            // %{ print(f"n_bytes_to_extract : {ids.n_bytes_to_extract}") %}
            let (
                extracted_key_subset, extracted_key_subset_len
            ) = extract_n_bytes_from_le_64_chunks_array(
                rlp,
                first_item_value_start_word,
                first_item_value_start_offset,
                n_bytes_to_extract,
                pow2_array,
            );

            // Check if the extracted key is contained is contained in the full key.
            let (contains_subkey) = assert_subset_in_key_be(
                key_subset=extracted_key_subset,
                key_subset_len=extracted_key_subset_len,
                key_subset_nibble_len=n_nibbles_in_first_item,
                key_be=key_be,
                key_be_nibbles=key_be_nibbles,
                key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
                n_nibbles_already_checked=n_nibbles_already_checked,
                cut_nibble=odd,
                pow2_array=pow2_array,
            );
            assert key_checked = contains_subkey;
            assert range_check_ptr_f = range_check_ptr;
            assert bitwise_ptr_f = bitwise_ptr;
            assert n_nibbles_already_checked_f = n_nibbles_already_checked +
                n_nibbles_in_first_item;
            assert pow2_array_f = pow2_array;
        } else {
            // if the first item is a single byte
            if (odd != 0) {
                // If the first item has an odd number of nibbles, since there are two nibbles in one byte, the second nibble needs to be checked
                let key_nibble = extract_nibble_from_key_be(
                    key_be,
                    key_be_nibbles,
                    key_be_leading_zeroes_nibbles,
                    n_nibbles_already_checked,
                    pow2_array,
                );
                let (_, first_item_nibble) = felt_divmod(first_item_prefix, 2 ** 4);
                if (key_nibble == first_item_nibble) {
                    assert key_checked = 1;
                } else {
                    assert key_checked = 0;
                }
                assert range_check_ptr_f = range_check_ptr;
                assert bitwise_ptr_f = bitwise_ptr;
                assert n_nibbles_already_checked_f = n_nibbles_already_checked + 1;
                assert pow2_array_f = pow2_array;
            } else {
                // If the first item has en even number of nibbles, since there are two nibbles in one byte, there is nothing to check.
                assert range_check_ptr_f = range_check_ptr;
                assert bitwise_ptr_f = bitwise_ptr;
                assert n_nibbles_already_checked_f = n_nibbles_already_checked;
                assert pow2_array_f = pow2_array;
                assert key_checked = 1;
            }
        }
        let range_check_ptr = range_check_ptr_f;
        let bitwise_ptr = bitwise_ptr_f;
        let pow2_array = pow2_array_f;
        let n_nibbles_already_checked = n_nibbles_already_checked_f;

        if (key_checked == 0) {
            // Key does not match, we have a non-inclusion. Return empty value.
            // Make sure nibbles checked will pass. We encode non-inclusion result as (-1) length.
            return (
                n_nibbles_already_checked=key_be_leading_zeroes_nibbles + key_be_nibbles,
                item_of_interest=rlp,
                item_of_interest_len=-1,
            );
        } else {
            // Key match and is included, return actual value.
            // Extract value or hash.
            let (second_item_value_starts_word, second_item_value_start_offset) = felt_divmod(
                second_item_value_starts_at_byte, 8
            );
            if (last_node != 0) {
                // Extract value
                let (value, value_len) = extract_n_bytes_from_le_64_chunks_array(
                    rlp,
                    second_item_value_starts_word,
                    second_item_value_start_offset,
                    second_item_bytes_len,
                    pow2_array,
                );
                return (
                    n_nibbles_already_checked=n_nibbles_already_checked,
                    item_of_interest=value,
                    item_of_interest_len=second_item_bytes_len,
                );
            } else {
                // Extract hash (32 bytes)
                // %{ print(f"Extracting hash in leaf/node case)") %}
                assert second_item_bytes_len = 32;
                let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                    rlp, second_item_value_starts_word, second_item_value_start_offset, pow2_array
                );
                return (
                    n_nibbles_already_checked=n_nibbles_already_checked,
                    item_of_interest=cast(&hash_le, felt*),
                    item_of_interest_len=32,
                );
            }
        }
    } else {
        // Node has more than 2 items : it's a branch.
        if (last_node != 0) {
            // %{ print(f"Branch case, last node : yes") %}

            // Branch is the last node in the proof.
            // For an inclusion, proof, key should already be fully checked at this point.
            // For a non inclusion proof (key hasn't been already checked despite last node), the item at the next nibble index should be empty.
            if (key_be_leading_zeroes_nibbles + key_be_nibbles != n_nibbles_already_checked) {
                let next_key_nibble = extract_nibble_from_key_be(
                    key_be,
                    key_be_nibbles,
                    key_be_leading_zeroes_nibbles,
                    n_nibbles_already_checked,
                    pow2_array,
                );
                let (
                    item_of_interest_start_word: felt, item_of_interest_start_offset: felt
                ) = get_branch_value_precomputed_offsets_1_2_3(
                    rlp,
                    next_key_nibble,
                    first_item_start_offset,
                    second_item_value_starts_at_byte,
                    third_item_starts_at_byte,
                    pow2_array,
                );

                let should_be_empty_prefix = extract_byte_at_pos(
                    rlp[item_of_interest_start_word], item_of_interest_start_offset, pow2_array
                );

                assert should_be_empty_prefix = 0x80;
                // Returns the length of the key as if the key was fully checked so the check in the outer function will pass.
                // Returns length of -1 to indicate non-inclusion.
                return (key_be_nibbles + key_be_leading_zeroes_nibbles, rlp, -1);
            } else {
                let (third_item_start_word, third_item_start_offset) = felt_divmod(
                    third_item_starts_at_byte, 8
                );
                let (
                    last_item_start_word, last_item_start_offset
                ) = jump_branch_node_till_element_at_index(
                    rlp, 2, 16, third_item_start_word, third_item_start_offset, pow2_array
                );  // we start jumping of the 3rd item (index 2) to the 17th item (index 16)
                tempvar last_item_bytes_len = bytes_len - (
                    last_item_start_word * 8 + last_item_start_offset
                );

                let (
                    last_item: felt*, last_item_len: felt
                ) = extract_n_bytes_from_le_64_chunks_array(
                    rlp,
                    last_item_start_word,
                    last_item_start_offset,
                    last_item_bytes_len,
                    pow2_array,
                );

                return (n_nibbles_already_checked, last_item, last_item_bytes_len);
            }
        } else {
            // %{ print(f"Branch case, last node : no") %}
            // Branch is not the last node in the proof. We need to extract the hash corresponding to the next nibble of the key.

            // Get the next nibble of the key.
            let next_key_nibble = extract_nibble_from_key_be(
                key_be,
                key_be_nibbles,
                key_be_leading_zeroes_nibbles,
                n_nibbles_already_checked,
                pow2_array,
            );
            // %{ print(f"Next Key nibble {ids.next_key_nibble}") %}
            let (
                local item_of_interest_start_word: felt, local item_of_interest_start_offset: felt
            ) = get_branch_value_precomputed_offsets_1_2_3(
                rlp,
                next_key_nibble,
                first_item_start_offset,
                second_item_value_starts_at_byte,
                third_item_starts_at_byte,
                pow2_array,
            );

            // Extract the hash at the correct coordinates.

            let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                rlp, item_of_interest_start_word, item_of_interest_start_offset, pow2_array
            );

            // Return the Uint256 hash as a felt* of length 2.
            return (n_nibbles_already_checked + 1, cast(&hash_le, felt*), 32);
        }
    }
}

func get_branch_value_precomputed_offsets_1_2_3{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    next_key_nibble: felt,
    first_item_start_offset: felt,
    second_item_value_starts_at_byte: felt,
    third_item_starts_at_byte: felt,
    pow2_array: felt*,
) -> (item_of_interest_start_word: felt, item_of_interest_start_offset: felt) {
    if (next_key_nibble == 0) {
        // Store coordinates of the first item's value.
        // %{ print(f"\t Branch case, key index = 0") %}
        return (0, first_item_start_offset + 1);
    } else {
        if (next_key_nibble == 1) {
            // Store coordinates of the second item's value.
            // %{ print(f"\t Branch case, key index = 1") %}

            let (q, r) = felt_divmod_8(second_item_value_starts_at_byte);
            return (q, r);
        } else {
            if (next_key_nibble == 2) {
                // Store coordinates of the third item's value.
                // %{ print(f"\t Branch case, key index = 2") %}
                let (q, r) = felt_divmod_8(third_item_starts_at_byte + 1);
                return (q, r);
            } else {
                // Store coordinates of the item's value at index next_key_nibble != (0, 1, 2).
                // %{ print(f"\t Branch case, key index {ids.next_key_nibble}") %}
                let (third_item_start_word, third_item_start_offset) = felt_divmod(
                    third_item_starts_at_byte, 8
                );
                let (item_start_word, item_start_offset) = jump_branch_node_till_element_at_index(
                    rlp=rlp,
                    item_start_index=2,
                    target_index=next_key_nibble,
                    prefix_start_word=third_item_start_word,
                    prefix_start_offset=third_item_start_offset,
                    pow2_array=pow2_array,
                );
                let (q, r) = felt_divmod(item_start_word * 8 + item_start_offset + 1, 8);
                return (q, r);
            }
        }
    }
}
// Jumps on a branch until index i is reached.
// params:
// - rlp: the branch node as an array of little endian 8 bytes chunks.
// - item_start_index: the index of the item to jump from.
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
