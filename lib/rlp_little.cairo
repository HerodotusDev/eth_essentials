from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_pow2,
    uint256_unsigned_div_rem,
    uint256_mul,
)
from starkware.cairo.common.alloc import alloc
from lib.utils import (
    felt_divmod_8,
    felt_divmod,
    get_0xff_mask,
    word_reverse_endian_64,
    bitwise_divmod,
    get_felt_bitlength_128,
    uint256_reverse_endian_no_padding,
    n_bits_to_n_bytes,
    get_uint256_bit_length,
    get_felt_n_nibbles,
    n_bits_to_n_nibbles,
    count_trailing_zeroes_128,
)

func n_nibbles_in_key{range_check_ptr}(key: Uint256, pow2_array: felt*) -> (res: felt) {
    let (num_bits_in_key) = get_uint256_bit_length(key, pow2_array);
    let (num_nibbles_in_key) = n_bits_to_n_nibbles(num_bits_in_key);
    return (res=num_nibbles_in_key);
}

// From a Uint256 number in little endian bytes representation,
// predict the number of leading zeroes nibbles before the number is converted to BE representation.
// Parameters:
// - x: the little endian representation of the number.
// - n_nibbles_after_reversion: the fixed # of nibbles in the number after reversion. This is known from RLP decoding.
// - cut_nibble: if 1, takes into account that the leftmost nibble in BE representation will be cut.
// - pow2_array: array of powers of 2.
// Example 1:
// LE input : 0x ab 0d 0f 00 : cut_nibble = 0
// BE reverted : 0x 00 0f 0d ab -> 3 leading zeroes.
// Example 2:
// LE input : 0x ab 0d 0f e0 : cut_nibble = 1
// BE reverted: 0x e0 0d 0f ab
// BE reverted + cut ("e" removed) : 0x 00 d0 fa b -> 2 leading zeroes.
func count_leading_zeroes_from_uint256_le_before_reversion{bitwise_ptr: BitwiseBuiltin*}(
    x: Uint256, n_nibbles_after_reversion: felt, cut_nibble: felt, pow2_array: felt*
) -> (res: felt) {
    alloc_locals;
    %{
        from tools.py.utils import parse_int_to_bytes, count_leading_zero_nibbles_from_hex
        reversed_hex = parse_int_to_bytes(ids.x.low + (2 ** 128) * ids.x.high)[::-1].hex()
        expected_leading_zeroes = count_leading_zero_nibbles_from_hex(reversed_hex[1:] if ids.cut_nibble == 1 else reversed_hex)
    %}
    local x_f: Uint256;
    local first_nibble_is_zero;
    assert x_f.high = x.high;
    if (cut_nibble != 0) {
        assert bitwise_ptr.x = x.low;
        assert bitwise_ptr.y = 0xffffffffffffffffffffffffffffff0f;
        assert bitwise_ptr[1].x = x.low;
        assert bitwise_ptr[1].y = 0xf;
        let xf_l = bitwise_ptr.x_and_y;
        assert x_f.low = xf_l;
        let first_nibble = bitwise_ptr[1].x_and_y;
        if (first_nibble == 0) {
            assert first_nibble_is_zero = 1;
            tempvar bitwise_ptr = bitwise_ptr + 2 * BitwiseBuiltin.SIZE;
        } else {
            assert first_nibble_is_zero = 0;
            tempvar bitwise_ptr = bitwise_ptr + 2 * BitwiseBuiltin.SIZE;
        }
    } else {
        assert x_f.low = x.low;
        assert bitwise_ptr.x = x.low;
        assert bitwise_ptr.y = 0xf0;
        let first_nibble = bitwise_ptr.x_and_y / 2 ** 4;
        if (first_nibble == 0) {
            assert first_nibble_is_zero = 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        } else {
            assert first_nibble_is_zero = 0;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        }
    }
    let (trailing_zeroes_low) = count_trailing_zeroes_128(x_f.low, pow2_array);
    if (trailing_zeroes_low == 16) {
        // The low part if full of zeroes bytes.
        // Need to analyze the high part.
        let (trailing_zeroes_high) = count_trailing_zeroes_128(x_f.high, pow2_array);
        if (trailing_zeroes_high == 16) {
            // The high part is also full of zeroes bytes.
            // The number of leading zeroes is then precisely the number of nibbles after reversion.
            return (res=n_nibbles_after_reversion);
        } else {
            // Need to analyse the first nibble after reversion.
            let first_non_zero_byte = extract_byte_at_pos(
                x_f.high, trailing_zeroes_high, pow2_array
            );
            let (first_nibble_after_reversion, _) = bitwise_divmod(first_non_zero_byte, 2 ** 4);
            if (first_nibble_after_reversion == 0) {
                tempvar res = 32 + 2 * trailing_zeroes_high - cut_nibble + 1;
                %{ assert ids.res == expected_leading_zeroes, f"Expected {expected_leading_zeroes} but got {ids.res}" %}
                return (res=res);
            } else {
                tempvar res = 32 + 2 * trailing_zeroes_high - cut_nibble;
                %{ assert ids.res == expected_leading_zeroes, f"Expected {expected_leading_zeroes} but got {ids.res}" %}

                return (res=res);
            }
        }
    } else {
        // Trailing zeroes bytes between [0, 15].
        if (trailing_zeroes_low == 0) {
            let res = first_nibble_is_zero;
            %{ assert ids.res == expected_leading_zeroes, f"Expected {expected_leading_zeroes} but got {ids.res}" %}
            return (res=res);
        } else {
            // Trailing zeroes bytes between [1, 15].

            // Need to check the first nibble after reversion.
            let first_non_zero_byte = extract_byte_at_pos(x_f.low, trailing_zeroes_low, pow2_array);
            // %{ print(f"{hex(ids.first_non_zero_byte)=}") %}
            local first_nibble_after_reversion;

            let (first_nibble_after_reversion, _) = bitwise_divmod(first_non_zero_byte, 2 ** 4);
            // %{ print(f"{hex(ids.first_nibble_after_reversion)=}") %}
            if (first_nibble_after_reversion == 0) {
                tempvar res = 2 * trailing_zeroes_low - cut_nibble + 1;
                %{ assert ids.res == expected_leading_zeroes, f"Expected {expected_leading_zeroes} but got {ids.res}" %}

                return (res=res);
            } else {
                tempvar res = 2 * trailing_zeroes_low - cut_nibble;
                %{ assert ids.res == expected_leading_zeroes, f"Expected {expected_leading_zeroes} but got {ids.res}" %}

                return (res=res);
            }
        }
    }
}

// Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
// Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
// returns bi such that i = byte_position
func extract_byte_at_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_position: felt, pow2_array: felt*
) -> felt {
    tempvar pow = pow2_array[8 * byte_position];
    assert bitwise_ptr.x = word_64_little;
    assert bitwise_ptr.y = 0xff * pow;
    let extracted_byte_at_pos = bitwise_ptr.x_and_y / pow;
    tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return extracted_byte_at_pos;
}

// Takes a 64 bit word with little endian bytes, returns the nibble at a given position as it would be in big endian.
// Input of the form: word_64_bits = n14 n15 n12 n13 n10 n11 n8 n9 n6 n7 n4 n5 n2 n3 n0 n1
// returns ni such that :
// i = 2 * byte_position if nibble_pos = 0
// i = 2 * byte_position + 1 if nibble_pos != 0
// nibble_pos is the position within the byte, first nibble of the byte is 0, second is 1 (here 1 <=> !=0 to avoid a range check).
func extract_nibble_at_byte_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_pos: felt, nibble_pos: felt, pow2_array: felt*
) -> felt {
    if (nibble_pos == 0) {
        tempvar pow = pow2_array[8 * byte_pos + 4];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * pow;
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    } else {
        tempvar pow = pow2_array[8 * byte_pos];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * pow;
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    }
}

func key_subset_to_uint256(key_subset: felt*, key_subset_len: felt) -> Uint256 {
    if (key_subset_len == 1) {
        let res = Uint256(low=key_subset[0], high=0);
        return res;
    }
    if (key_subset_len == 2) {
        let res = Uint256(low=key_subset[0] + key_subset[1] * 2 ** 64, high=0);
        return res;
    }
    if (key_subset_len == 3) {
        let res = Uint256(low=key_subset[0] + key_subset[1] * 2 ** 64, high=key_subset[2]);
        return res;
    }
    if (key_subset_len == 4) {
        let res = Uint256(
            low=key_subset[0] + key_subset[1] * 2 ** 64,
            high=key_subset[2] + key_subset[3] * 2 ** 64,
        );
        return res;
    }
    assert 1 = 0;
    // Should never happen, key is at most 256 bits (4x64 bits words).
    let res = Uint256(low=0, high=0);
    return res;
}

// Asserts that a subset of the key is in the key in big endian at the correct position given:
// the length of the key subset, the full key, and the nibbles already checked in the full key.
// - key_subset: array of 8 little endian bytes extracted from rlp array.
// - key_subset_len: the length of the key subset (in # of words)
// - key_subset_nibble_len: the number of nibbles in the key subset. Deduced from rlp encoding.
// - key_be: the key to check as a big endian Uint256 number.
// - key_be_nibbles: the number of nibbles in the key (excluding leading zeroes).
// - key_be_leading_zeroes_nibbles: the number of leading zeroes nibbles in the key.
// - n_nibbles_already_checked: the number of nibbles already checked in the key.
// - cut_nibble: 1 if the first nibble from the extracted key needs to be cut. 0 otherwise.
// - pow2_array: array of powers of 2.
// Ex : Full Key is 0x012345678
// Nibbles checked is 2
// Key subset is 0x4523 (little endian)
// First key subset is going to be reversed to big endian : 0x2345
// Then Full Key will first be cut to 0x2345678 (n_nibbles checked removed on the left)
// Then again cut to 0x2345 (keep key_subset_nibble_len on the left)
// Then the key subset will be asserted against the cut key.
func assert_subset_in_key_be{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    key_subset: felt*,
    key_subset_len: felt,
    key_subset_nibble_len: felt,
    key_be: Uint256,
    key_be_nibbles: felt,
    key_be_leading_zeroes_nibbles: felt,
    n_nibbles_already_checked: felt,
    cut_nibble: felt,
    pow2_array: felt*,
) -> (res: felt) {
    alloc_locals;

    // Get the little endian 256 bit number from the extracted 64 bit le words array :
    let key_subset_256_le = key_subset_to_uint256(key_subset, key_subset_len);
    // %{
    //     key_subset_256_le = hex(ids.key_subset_256_le.low + ids.key_subset_256_le.high*2**128)[2:]
    //     print(f"Key subset 256 le: {key_subset_256_le}")
    // %}
    let (key_subset_be_tmp: Uint256, n_bytes: felt) = uint256_reverse_endian_no_padding(
        key_subset_256_le, pow2_array
    );
    // %{
    //     orig_key = hex(ids.key_be.low + ids.key_be.high*2**128)[2:]
    //     key_subset = hex(ids.key_subset_be_tmp.low + ids.key_subset_be_tmp.high*2**128)[2:]
    //     print(f"Orig key: {orig_key}, n_nibbles={len(orig_key)}")
    //     print(f"Key subset: {key_subset}, n_nibbles={len(key_subset)}")
    // %}

    // Cut nibble of the key subset if needed from the leftmost position. 0x123 -> 0x23
    local key_subset_be: Uint256;
    local bitwise_ptr_f: BitwiseBuiltin*;
    if (cut_nibble != 0) {
        // %{ print(f"Cut nibble") %}
        if (key_subset_be_tmp.high != 0) {
            let (_, key_susbet_be_high) = bitwise_divmod(
                key_subset_be_tmp.high, pow2_array[8 * (n_bytes - 16) - 4]
            );
            assert key_subset_be.low = key_subset_be_tmp.low;
            assert key_subset_be.high = key_susbet_be_high;
            assert bitwise_ptr_f = bitwise_ptr;
        } else {
            let (_, key_susbet_be_low) = bitwise_divmod(
                key_subset_be_tmp.low, pow2_array[8 * n_bytes - 4]
            );
            assert key_subset_be.low = key_susbet_be_low;
            assert key_subset_be.high = 0;
            assert bitwise_ptr_f = bitwise_ptr;
        }
    } else {
        assert key_subset_be.low = key_subset_be_tmp.low;
        assert key_subset_be.high = key_subset_be_tmp.high;
        assert bitwise_ptr_f = bitwise_ptr;
    }
    let bitwise_ptr = bitwise_ptr_f;
    // %{
    //     key_subset_cut = hex(ids.key_subset_be.low + ids.key_subset_be.high*2**128)[2:]
    //     print(f"Key subset cut: {key_subset_cut}, n_nibbles={len(key_subset_cut)}")
    // %}
    local bitwise_ptr_f: BitwiseBuiltin*;
    local range_check_ptr_f;
    local key_subset_be_final: Uint256;
    let (key_subset_bits) = get_uint256_bit_length(key_subset_be, pow2_array);
    let (key_subset_nibbles) = n_bits_to_n_nibbles(key_subset_bits);

    // Remove n_nibbles_already_checked nibbles from the left part of the key
    // %{ print(f"Remove {ids.n_nibbles_already_checked} nibbles from the left part of the key") %}
    let (u256_power) = uint256_pow2(
        Uint256((key_be_nibbles + key_be_leading_zeroes_nibbles - n_nibbles_already_checked) * 4, 0)
    );
    let (_, key_shifted) = uint256_unsigned_div_rem(key_be, u256_power);
    // %{ print(f"Key shifted: {hex(ids.key_shifted.low + ids.key_shifted.high*2**128)}") %}

    // Remove rightmost part of the key, keep only key_subset_nibble_len nibbles on the left
    // %{
    //     print(f"Remove rightmost part of the key, keep only {ids.key_subset_nibble_len} nibbles on the left")
    //     power = ids.key_be_nibbles + ids.key_be_leading_zeroes_nibbles - ids.n_nibbles_already_checked - ids.key_subset_nibble_len
    //     print(f"Computing 2**({power}) = {power/4} nibbles = {power/8} bytes")
    // %}
    let (u256_power) = uint256_pow2(
        Uint256(
            4 * (
                key_be_nibbles +
                key_be_leading_zeroes_nibbles -
                n_nibbles_already_checked -
                key_subset_nibble_len
            ),
            0,
        ),
    );
    let (key_shifted, _) = uint256_unsigned_div_rem(key_shifted, u256_power);
    // %{ print(f"Key shifted final: {hex(ids.key_shifted.low + ids.key_shifted.high*2**128)}") %}

    if (key_subset_nibbles != key_subset_nibble_len) {
        // Nibbles lens don't match.
        // %{ print(f"Nibbles lens don't match: {ids.key_subset_nibbles=} != {ids.key_subset_nibble_len=}") %}
        // This either come from :
        // 1. the leftmost nibbles of the BE key (right most nibbles of the LE key) being 0's
        // 2. the the rightmost nibbles of the BE key being 0's.

        // Handle 1. : count leftfmost nibbles of the BE key from the rightmost nibbles of the LE key:
        let (n_leading_zeroes_nibbles) = count_leading_zeroes_from_uint256_le_before_reversion(
            key_subset_256_le, key_subset_nibble_len, cut_nibble, pow2_array
        );
        // %{ print(f"n_leading_zeroes_nibbles: {ids.n_leading_zeroes_nibbles}") %}
        if (key_subset_nibble_len - (key_subset_nibbles + n_leading_zeroes_nibbles) != 0) {
            // Handle 2. : Right pad the BE key with 0's until the expected length.
            // %{ print(f"Right pad with {ids.key_subset_nibble_len - (ids.key_subset_nibbles + ids.n_leading_zeroes_nibbles)} 0's") %}
            let (u256_pow) = uint256_pow2(
                Uint256(
                    (key_subset_nibble_len - (key_subset_nibbles + n_leading_zeroes_nibbles)) * 4, 0
                ),
            );
            let (res_tmp, _) = uint256_mul(key_subset_be, u256_pow);
            assert key_subset_be_final.low = res_tmp.low;
            assert key_subset_be_final.high = res_tmp.high;
            assert range_check_ptr_f = range_check_ptr;
            assert bitwise_ptr_f = bitwise_ptr;
        } else {
            // %{ print(f"Do nothing. Nibble lens including leading zeroes match") %}
            // Handle 1. Nothing to do. Nibble lens including leading zeroes match.
            assert key_subset_be_final.low = key_subset_be.low;
            assert key_subset_be_final.high = key_subset_be.high;
            assert range_check_ptr_f = range_check_ptr;
            assert bitwise_ptr_f = bitwise_ptr;
        }
    } else {
        // %{ print(f"Do nothing. Nibble lens match") %}
        // Do nothing if the nibble lens already match. Assertions will pass.
        assert key_subset_be_final.low = key_subset_be.low;
        assert key_subset_be_final.high = key_subset_be.high;
        assert range_check_ptr_f = range_check_ptr;
        assert bitwise_ptr_f = bitwise_ptr;
    }
    let bitwise_ptr = bitwise_ptr_f;
    let range_check_ptr = range_check_ptr_f;
    // %{ print(f"Key subset final: {hex(ids.key_subset_be_final.low + ids.key_subset_be_final.high*2**128)}") %}

    // %{ print(f"key subset expect: {hex(ids.key_shifted.low + ids.key_shifted.high*2**128)}") %}
    if (key_subset_be_final.low == key_shifted.low) {
        if (key_subset_be_final.high == key_shifted.high) {
            return (1,);
        } else {
            return (0,);
        }
    } else {
        return (0,);
    }
}

// From a 256 bit key in big endian of the form :
// key = n0 n1 n2 ... n62 n63
// returns ni such that i = nibble_index
// Params:
// key: the Uint256 number representing the key in big endian
// key_nibbles: the number of nibbles in the key (excluding leading zeroes)
// key_leading_zeroes_nibbles: the number of leading zeroes nibbles in the key
// nibble_index: the index of the nibble to extract
// pow2_array: array of powers of 2
func extract_nibble_from_key_be{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    key: Uint256,
    key_nibbles: felt,
    key_leading_zeroes_nibbles: felt,
    nibble_index: felt,
    pow2_array: felt*,
) -> felt {
    alloc_locals;
    local is_zero;
    %{ ids.is_zero = 1 if ids.nibble_index <= (ids.key_leading_zeroes_nibbles - 1) else 0 %}
    if (is_zero != 0) {
        // %{ print(f"\t {ids.nibble_index} <= {ids.key_leading_zeroes_nibbles - 1}") %}
        // nibble_index is in [0, key_leading_zeroes_nibbles - 1]
        assert [range_check_ptr] = (key_leading_zeroes_nibbles - 1) - nibble_index;
        tempvar range_check_ptr = range_check_ptr + 1;
        return 0;
    } else {
        // %{ print(f"\t {ids.nibble_index} > {ids.key_leading_zeroes_nibbles - 1}") %}
        // nibble_index is >= key_leading_zeroes_nibbles
        assert [range_check_ptr] = nibble_index - key_leading_zeroes_nibbles;
        tempvar range_check_ptr = range_check_ptr + 1;
        // Reindex nibble_index to start from 0 accounting for the leading zeroes
        // Ex: key is 0x00abc. Nibble index is 2 (=> nibble is "a"). Reindexed nibble index is then 2-2=0.
        let nibble_index = nibble_index - key_leading_zeroes_nibbles;
        local get_nibble_from_low: felt;
        // we get the nibble from low part of key either if :
        // - nibble_index is in [0, 31] and key_nibbles <= 32
        // - nibble_index is in [32, 63] and key_nibbles > 32
        // Consequently, we get the nibble from high part of the key only if :
        // - nibble_index is in [0, 31] and key_nibbles > 32
        %{ ids.get_nibble_from_low = 1 if (0 <= ids.nibble_index <= 31 and ids.key_nibbles <= 32) or (32 <= ids.nibble_index <= 63 and ids.key_nibbles > 32) else 0 %}
        // %{
        //      print(f"Key low: {hex(ids.key.low)}")
        //      print(f"Key high: {hex(ids.key.high)}")
        //      print(f"nibble_index: {ids.nibble_index}")
        //      print(f"key_nibbles: {ids.key_nibbles}")
        //      print(f"key_leading_zeroes_nibbles: {ids.key_leading_zeroes_nibbles}")
        // %}
        %{
            key_hex = ids.key_leading_zeroes_nibbles * '0' + hex(ids.key.low + (2 ** 128) * ids.key.high)[2:]
            expected_nibble = int(key_hex[ids.nibble_index + ids.key_leading_zeroes_nibbles], 16)
        %}
        if (get_nibble_from_low != 0) {
            local offset;
            if (key.high != 0) {
                // key_nibbles > 32. Then nibble_index must be in [32, 63]
                assert [range_check_ptr] = 31 - (nibble_index - 32);
                assert offset = pow2_array[4 * (32 - nibble_index - 1)];
            } else {
                // key_nibbles <= 32. Then nibble_index must be in [0, 31]
                assert [range_check_ptr] = 31 - nibble_index;
                assert offset = pow2_array[4 * (key_nibbles - nibble_index - 1)];
            }
            tempvar range_check_ptr = range_check_ptr + 1;
            assert bitwise_ptr.x = key.low;
            assert bitwise_ptr.y = 0xf * offset;
            tempvar extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            %{ assert ids.extracted_nibble_at_pos == expected_nibble, f"extracted_nibble_at_pos={ids.extracted_nibble_at_pos} expected_nibble={expected_nibble}" %}
            return extracted_nibble_at_pos;
        } else {
            // Extract nibble from high part of key
            // nibble index must be in [0, 31] and key_nibbles > 32
            assert [range_check_ptr] = 31 - nibble_index;
            if (key.high == 0) {
                assert 1 = 0;
            }
            tempvar offset = pow2_array[4 * (key_nibbles - 32 - nibble_index - 1)];
            assert bitwise_ptr.x = key.high;
            assert bitwise_ptr.y = 0xf * offset;
            tempvar extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
            tempvar range_check_ptr = range_check_ptr + 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            %{ assert ids.extracted_nibble_at_pos == expected_nibble, f"extracted_nibble_at_pos={ids.extracted_nibble_at_pos} expected_nibble={expected_nibble}" %}

            return extracted_nibble_at_pos;
        }
    }
}

// Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
// Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
// returns [b(i+n-1) ... b(i+1) bi] such that i = pos and n = n.
// Doesn't check if 0 <= pos <= 7 and pos + n <= 7
// Returns 0 if n=0.
func extract_n_bytes_at_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, pos: felt, n: felt, pow2_array: felt*
) -> felt {
    // %{ print(f"extracting {ids.n} bytes at pos {ids.pos} from {hex(ids.word_64_little)}") %}
    let x_mask = get_0xff_mask(n);
    // %{ print(f"x_mask for len {ids.n}: {hex(ids.x_mask)}") %}
    assert bitwise_ptr[0].x = word_64_little;
    assert bitwise_ptr[0].y = x_mask * pow2_array[8 * (pos)];
    tempvar res = bitwise_ptr[0].x_and_y;
    // %{ print(f"tmp : {hex(ids.res)}") %}
    tempvar extracted_bytes = bitwise_ptr[0].x_and_y / pow2_array[8 * pos];
    tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return extracted_bytes;
}

func extract_le_hash_from_le_64_chunks_array{range_check_ptr}(
    array: felt*, start_word: felt, start_offset: felt, pow2_array: felt*
) -> (extracted_hash: Uint256) {
    alloc_locals;
    tempvar pow = pow2_array[8 * start_offset];
    tempvar pow_0 = pow2_array[64 - 8 * start_offset];
    tempvar pow_1 = 2 ** 64 * pow_0;
    let (arr_0, _) = felt_divmod(array[start_word], pow);
    let arr_1 = array[start_word + 1];
    let (arr_2_left, arr_2_right) = felt_divmod(array[start_word + 2], pow);
    let arr_3 = array[start_word + 3];
    let (_, arr_4) = felt_divmod(array[start_word + 4], pow);

    let res_low = arr_2_right * pow_1 + arr_1 * pow_0 + arr_0;
    let res_high = arr_4 * pow_1 + arr_3 * pow_0 + arr_2_left;

    let res = Uint256(low=res_low, high=res_high);
    return (res,);
}

// From an array of 64 bit words in little endia bytesn, extract n bytes starting at start_word and start_offset.
// array is of the form [b7 b6 b5 b4 b3 b2 b1 b0, b15 b14 b13 b12 b11 b10 b9 b8, ...]
// start_word is the index of the first word to extract from (starting from 0)
// start_offset is the offset in bytes from the start of the word (in [[0, 7]])
// returns an array of the form [c7 c6 c5 c4 c3 c2 c1 c0, c15 c14 c13 c12 c11 c10 c9 c8, ..., cn-1 cn-2 ...]
// (last word might be less than 8 bytes),
// such that ci = b_(8*start_word + start_offset + i)
func extract_n_bytes_from_le_64_chunks_array{range_check_ptr}(
    array: felt*, start_word: felt, start_offset: felt, n_bytes: felt, pow2_array: felt*
) -> (extracted_bytes: felt*, n_words: felt) {
    alloc_locals;
    let (local res: felt*) = alloc();

    let (local q, local n_ending_bytes) = felt_divmod_8(n_bytes);

    local n_words: felt;

    if (q == 0) {
        if (n_ending_bytes == 0) {
            // 0 bytes to extract, forbidden.
            assert 1 = 0;
        } else {
            // 1 to 7 bytes to extract.
            assert n_words = 1;
        }
    } else {
        if (n_ending_bytes == 0) {
            assert n_words = q;
        } else {
            assert n_words = q + 1;
        }
    }

    // %{
    //     print(f"Start word: {ids.start_word}, start_offset: {ids.start_offset}, n_bytes: {ids.n_bytes}")
    //     print(f"n_words={ids.n_words} n_ending_bytes={ids.n_ending_bytes} \n")
    // %}

    // Handle trivial case where start_offset = 0., words can be copied directly.
    if (start_offset == 0) {
        // %{ print(f"copying {ids.q} words... ") %}
        array_copy(src=array + start_word, dst=res, n=q, index=0);
        if (n_ending_bytes != 0) {
            let (_, last_word) = felt_divmod(array[start_word + q], pow2_array[8 * n_ending_bytes]);
            assert res[q] = last_word;
            return (res, n_words);
        }
        return (res, n_words);
    }

    local pow_cut = pow2_array[8 * start_offset];
    local pow_acc = pow2_array[64 - 8 * start_offset];

    let (local current_word, _) = felt_divmod(array[start_word], pow_cut);

    if (n_words == 1) {
        local needs_next_word: felt;
        local avl_bytes_in_word = 8 - start_offset;
        %{ ids.needs_next_word = 1 if ids.n_bytes > ids.avl_bytes_in_word else 0 %}
        if (needs_next_word == 0) {
            // %{ print(f"current_word={hex(ids.current_word)}") %}
            let (_, last_word) = felt_divmod(current_word, pow2_array[8 * n_ending_bytes]);
            assert res[0] = last_word;
            return (res, 1);
        } else {
            // %{ print(f"needs next word, avl_bytes_in_word={ids.avl_bytes_in_word}") %}
            // %{ print(f"current_word={hex(ids.current_word)}") %}

            let (_, last_word) = felt_divmod(
                array[start_word + 1], pow2_array[8 * (n_bytes - 8 + start_offset)]
            );
            assert res[0] = current_word + last_word * pow_acc;
            return (res, 1);
        }
    }

    // %{
    //     from math import log2
    //     print(f"pow_acc = 2**{log2(ids.pow_acc)}, pow_cut = 2**{log2(ids.pow_cut)}")
    // %}
    local range_check_ptr = range_check_ptr;
    local n_words_to_handle_in_loop;

    if (n_ending_bytes != 0) {
        assert n_words_to_handle_in_loop = n_words - 1;
    } else {
        assert n_words_to_handle_in_loop = n_words;
    }

    tempvar current_word = current_word;
    tempvar n_words_handled = 0;
    tempvar i = 1;

    cut_loop:
    let i = [ap - 1];
    let n_words_handled = [ap - 2];
    let current_word = [ap - 3];
    // %{ print(f"enter loop : {ids.i} {ids.n_words_handled}/{ids.n_words}") %}
    %{ memory[ap] = 1 if (ids.n_words_to_handle_in_loop - ids.n_words_handled) == 0 else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    // Inlined felt_divmod (unsigned_div_rem).
    let q = [ap];
    let r = [ap + 1];
    %{ ids.q, ids.r = divmod(memory[ids.array + ids.start_word + ids.i], ids.pow_cut) %}
    ap += 2;
    // %{
    //     print(f"val={memory[ids.array + ids.start_word + ids.i]} q={ids.q} r={ids.r}")
    // %}
    tempvar offset = 3 * n_words_handled;
    assert [range_check_ptr + offset] = q;
    assert [range_check_ptr + offset + 1] = r;
    assert [range_check_ptr + offset + 2] = pow_cut - r - 1;
    assert q * pow_cut + r = array[start_word + i];
    // done inlining felt_divmod.

    assert res[n_words_handled] = current_word + r * pow_acc;
    // %{ print(f"new word : {memory[ids.res + ids.n_words_handled]}") %}
    [ap] = q, ap++;
    [ap] = n_words_handled + 1, ap++;
    [ap] = i + 1, ap++;
    jmp cut_loop;

    end_loop:
    assert n_words_to_handle_in_loop - n_words_handled = 0;
    tempvar range_check_ptr = range_check_ptr + 3 * n_words_handled;

    if (n_ending_bytes != 0) {
        // %{ print(f"handling last word...") %}
        let (current_word, _) = felt_divmod(array[start_word + n_words_handled], pow_cut);
        local needs_next_word: felt;
        local avl_bytes_in_word = 8 - start_offset;
        %{ ids.needs_next_word = 1 if ids.n_ending_bytes > ids.avl_bytes_in_word else 0 %}
        if (needs_next_word == 0) {
            let (_, last_word) = felt_divmod(current_word, pow2_array[8 * n_ending_bytes]);
            assert res[n_words_handled] = last_word;
            return (res, n_words);
        } else {
            let (_, last_word) = felt_divmod(
                array[start_word + n_words_handled + 1],
                pow2_array[8 * (n_ending_bytes - 8 + start_offset)],
            );
            assert res[n_words_handled] = current_word + last_word * pow_acc;
            return (res, n_words);
        }
    }

    return (res, n_words_handled);
}

func array_copy(src: felt*, dst: felt*, n: felt, index: felt) {
    if (index == n) {
        return ();
    } else {
        assert dst[index] = src[index];
        return array_copy(src=src, dst=dst, n=n, index=index + 1);
    }
}

// // Jumps n items in a rlp consisting of only single byte, short string and long string items.
// // params:
// // - rlp: little endian 8 bytes chunks.
// // - already_jumped_items: the number of items already jumped. Must be 0 at the first call.
// // - n_items_to_jump: the number of items to jump in the rlp.
// // - prefix_start_word: the word of the prefix to jump from.
// // - prefix_start_offset: the offset of the prefix to jump from.
// // - last_item_bytes_len: the number of bytes of the last item of the branch node. (Must correspond to the initial item bytes length if n_items_to_jump = 0, otherwise any value is fine)
// // - pow2_array: array of powers of 2.
// // returns:
// // - the word number of the item to jump to.
// // - the offset of the item to jump to.
// // - the number of bytes of the item to jump to.
// func jump_n_items_from_item{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
//     rlp: felt*,
//     already_jumped_items: felt,
//     n_items_to_jump: felt,
//     prefix_start_word: felt,
//     prefix_start_offset: felt,
//     last_item_bytes_len: felt,
//     pow2_array: felt*,
// ) -> (start_word: felt, start_offset: felt, bytes_len: felt) {
//     alloc_locals;

// if (already_jumped_items == n_items_to_jump) {
//         return (prefix_start_word, prefix_start_offset, last_item_bytes_len);
//     }

// let item_prefix = extract_byte_at_pos(rlp[prefix_start_word], prefix_start_offset, pow2_array);
//     local item_type: felt;
//     %{
//         if 0x00 <= ids.item_prefix <= 0x7f:
//             ids.item_type = 0
//             #print(f"item : single byte")
//         elif 0x80 <= ids.item_prefix <= 0xb7:
//             ids.item_type = 1
//             #print(f"item : short string at item {ids.item_start_index} {ids.item_prefix - 0x80} bytes")
//         elif 0xb8 <= ids.second_item_prefix <= 0xbf:
//             ids.item_type = 2
//             #print(f"ong string (len_len {ids.second_item_prefix - 0xb7} bytes)")
//         else:
//             print(f"Unsupported item type {ids.item_prefix}. Only single bytes, short or long strings are supported.")
//     %}

// if (item_type == 0) {
//         // Single byte. We need to go further by one byte.
//         assert [range_check_ptr] = 0x7f - item_prefix;
//         tempvar range_check_ptr = range_check_ptr + 1;
//         if (prefix_start_offset + 1 == 8) {
//             // We need to jump to the next word.
//             return jump_n_items_from_item(
//                 rlp,
//                 already_jumped_items + 1,
//                 n_items_to_jump,
//                 prefix_start_word + 1,
//                 0,
//                 1,
//                 pow2_array,
//             );
//         } else {
//             return jump_n_items_from_item(
//                 rlp,
//                 already_jumped_items + 1,
//                 n_items_to_jump,
//                 prefix_start_word,
//                 prefix_start_offset + 1,
//                 1,
//                 pow2_array,
//             );
//         }
//     } else {
//         if (item_type == 1) {
//             // Short string.
//             assert [range_check_ptr] = item_prefix - 0x80;
//             assert [range_check_ptr + 1] = 0xb7 - item_prefix;
//             tempvar range_check_ptr = range_check_ptr + 2;
//             tempvar short_string_bytes_len = item_prefix - 0x80;
//             let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
//                 prefix_start_word * 8 + prefix_start_offset + 1 + short_string_bytes_len
//             );
//             return jump_n_items_from_item(
//                 rlp,
//                 already_jumped_items + 1,
//                 n_items_to_jump,
//                 next_item_start_word,
//                 next_item_start_offset,
//                 short_string_bytes_len,
//                 pow2_array,
//             );
//         } else {
//             // Long string.
//             assert [range_check_ptr] = item_prefix - 0xb8;
//             assert [range_check_ptr + 1] = 0xbf - item_prefix;
//             tempvar range_check_ptr = range_check_ptr + 2;
//             tempvar len_len = item_prefix - 0xb7;

// local len_len_start_word: felt;
//             local len_len_start_offset: felt;

// if (prefix_start_offset + 1 == 8) {
//                 assert len_len_start_word = prefix_start_word + 1;
//                 assert len_len_start_offset = 0;
//             } else {
//                 assert len_len_start_word = prefix_start_word;
//                 assert len_len_start_offset = prefix_start_offset + 1;
//             }

// let (
//                 len_len_bytes: felt*, len_len_n_words: felt
//             ) = extract_n_bytes_from_le_64_chunks_array(
//                 rlp, len_len_start_word, len_len_start_offset, len_len, pow2_array
//             );
//             assert len_len_n_words = 1;

// local long_string_bytes_len: felt;

// if (len_len == 1) {
//                 // No need to reverse, only one byte.
//                 assert long_string_bytes_len = len_len_bytes[0];
//             } else {
//                 let (long_string_bytes_len_tmp) = word_reverse_endian_64(len_len_bytes[0]);
//                 assert long_string_bytes_len = long_string_bytes_len_tmp;
//             }

// let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
//                 prefix_start_word * 8 + prefix_start_offset + 1 + len_len + long_string_bytes_len
//             );

// return jump_n_items_from_item(
//                 rlp,
//                 already_jumped_items + 1,
//                 n_items_to_jump,
//                 next_item_start_word,
//                 next_item_start_offset,
//                 long_string_bytes_len,
//                 pow2_array,
//             );
//         }
//     }
// }
