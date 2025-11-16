from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.uint256 import (
    Uint256,
    SHIFT,
    word_reverse_endian,
    uint256_reverse_endian,
    ALL_ONES,
)
from starkware.cairo.common.registers import get_fp_and_pc

const DIV_32 = 2 ** 32;
const DIV_32_MINUS_1 = DIV_32 - 1;
const PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481;

// Takes the hex representation and count the number of zeroes.
// Ie: returns the number of trailing zeroes bytes.
// If x is 0, returns 16.
func count_trailing_zeroes_128{bitwise_ptr: BitwiseBuiltin*}(x: felt, pow2_array: felt*) -> (
    res: felt
) {
    alloc_locals;

    if (x == 0) {
        return (res=16);
    }

    local trailing_zeroes_bytes;
    %{
        from tools.py.utils import count_trailing_zero_bytes_from_int
        ids.trailing_zeroes_bytes = count_trailing_zero_bytes_from_int(ids.x)
    %}
    // Verify.
    if (trailing_zeroes_bytes == 0) {
        // Make sure the last byte is not zero.
        let (_, last_byte) = bitwise_divmod(x, 2 ** 8);
        if (last_byte == 0) {
            assert 1 = 0;  // Add unsatisfiability check.
            return (res=0);
        } else {
            return (res=0);
        }
    } else {
        // Make sure the last trailing_zeroes_bytes are zeroes.
        let (q, r) = bitwise_divmod(x, pow2_array[8 * trailing_zeroes_bytes]);
        assert r = 0;
        // Make sure the byte just before the last trailing_zeroes_bytes is not zero.
        let (_, first_non_zero_byte) = bitwise_divmod(q, 2 ** 8);
        if (first_non_zero_byte == 0) {
            assert 1 = 0;  // Add unsatisfiability check.
            return (res=0);
        } else {
            return (res=trailing_zeroes_bytes);
        }
    }
}

// Returns the number of bytes in a number with n_bits bits.
// Assumptions:
// - 0 <= n_bits < 8 * RC_BOUND
func n_bits_to_n_bytes{range_check_ptr: felt}(n_bits: felt) -> (res: felt) {
    if (n_bits == 0) {
        return (res=0);
    }
    let (q, r) = felt_divmod_8(n_bits);
    if (q == 0) {
        return (res=1);
    }
    if (r == 0) {
        return (res=q);
    }
    return (res=q + 1);
}

// Returns the number of nibbles in a number with n_bits bits.
// Assumptions:
// - 0 <= n_bits < 4 * RC_BOUND
func n_bits_to_n_nibbles{range_check_ptr: felt}(n_bits: felt) -> (res: felt) {
    if (n_bits == 0) {
        return (res=0);
    }
    let (q, r) = felt_divmod(n_bits, 4);
    if (q == 0) {
        return (res=1);
    }
    if (r == 0) {
        return (res=q);
    }
    return (res=q + 1);
}

// Returns the number of bytes in a 128 bits number.
// Assumptions:
// - 0 <= x < 2^128
func get_felt_n_bytes_128{range_check_ptr: felt}(x: felt, pow2_array: felt*) -> (n_bytes: felt) {
    let n_bits = get_felt_bitlength_128{pow2_array=pow2_array}(x);
    let (n_bytes) = n_bits_to_n_bytes(n_bits);
    return (n_bytes,);
}

// Returns the number of nibbles in a 128 bits number.
func get_felt_n_nibbles{range_check_ptr: felt}(x: felt, pow2_array: felt*) -> (n_nibbles: felt) {
    let n_bits = get_felt_bitlength_128{pow2_array=pow2_array}(x);
    let (n_nibbles) = n_bits_to_n_nibbles(n_bits);
    return (n_nibbles,);
}
// Returns the total number of bits in the uint256 number.
// Assumptions :
// - 0 <= x < 2^256
// Returns:
// - nbits: felt - Total number of bits in the uint256 number.
func get_uint256_bit_length{range_check_ptr}(x: Uint256, pow2_array: felt*) -> (nbits: felt) {
    alloc_locals;
    with pow2_array {
        if (x.high != 0) {
            let x_bit_high = get_felt_bitlength_128(x.high);
            return (nbits=128 + x_bit_high);
        } else {
            if (x.low != 0) {
                let x_bit_low = get_felt_bitlength_128(x.low);
                return (nbits=x_bit_low);
            } else {
                return (nbits=0);
            }
        }
    }
}

// Takes a uint128 number, reverse its byte endianness without adding right-padding
// Ex :
// Input = 0x123456
// Output = 0x563412
// Input = 0x123
// Output = 0x0312
func uint128_reverse_endian_no_padding{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    x: felt, pow2_array: felt*
) -> (res: felt, n_bytes: felt) {
    alloc_locals;
    let (num_bytes_input) = get_felt_n_bytes_128(x, pow2_array);
    let (x_reversed) = word_reverse_endian(x);
    let (num_bytes_reversed) = get_felt_n_bytes_128(x_reversed, pow2_array);
    let (trailing_zeroes_input) = count_trailing_zeroes_128(x, pow2_array);

    if (num_bytes_input != num_bytes_reversed) {
        // %{ print(f"\tinput128: {hex(ids.x)}_{ids.num_bytes_input}bytes") %}
        // %{ print(f"\treversed: {hex(ids.x_reversed)}_{ids.num_bytes_reversed}bytes") %}
        let (x_reversed, r) = bitwise_divmod(
            x_reversed,
            pow2_array[8 * (num_bytes_reversed - num_bytes_input + trailing_zeroes_input)],
        );
        assert r = 0;  // Sanity check.
        // %{
        //     import math
        //     print(f"\treversed_fixed: {hex(ids.x_reversed)}_{math.ceil(ids.x_reversed.bit_length() / 8)}bytes")
        // %}
        return (res=x_reversed, n_bytes=num_bytes_input);
    }
    return (res=x_reversed, n_bytes=num_bytes_input);
}

// Takes a uint256 number, reverse its byte endianness without adding right-padding and returns the number of bytes.
func uint256_reverse_endian_no_padding{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    x: Uint256, pow2_array: felt*
) -> (res: Uint256, n_bytes: felt) {
    alloc_locals;
    if (x.high != 0) {
        let (high_reversed, n_bytes_high) = uint128_reverse_endian_no_padding(x.high, pow2_array);
        // %{ print(f"High_Rev: {hex(ids.high_reversed)}_{ids.high_reversed.bit_length()}b {ids.n_bytes_high}bytes") %}
        let (low_reversed) = word_reverse_endian(x.low);
        // %{ print(f"Low_rev: {hex(ids.low_reversed)}_{ids.low_reversed.bit_length()}b") %}

        let (q, r) = bitwise_divmod(low_reversed, pow2_array[8 * (16 - n_bytes_high)]);
        // %{ print(f"Q: {hex(ids.q)}") %}
        // %{ print(f"R: {hex(ids.r)}") %}
        return (
            res=Uint256(low=high_reversed + pow2_array[8 * n_bytes_high] * r, high=q),
            n_bytes=16 + n_bytes_high,
        );
    } else {
        let (low_reversed, n_bytes_low) = uint128_reverse_endian_no_padding(x.low, pow2_array);
        return (res=Uint256(low=low_reversed, high=0), n_bytes=n_bytes_low);
    }
}

// Adds two integers. Returns the result as a 256-bit integer and the (1-bit) carry.
// Strictly equivalent and faster version of common.uint256.uint256_add using the same whitelisted hint.
func uint256_add{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256, carry: felt) {
    alloc_locals;
    local carry_low: felt;
    local carry_high: felt;
    %{
        sum_low = ids.a.low + ids.b.low
        ids.carry_low = 1 if sum_low >= ids.SHIFT else 0
        sum_high = ids.a.high + ids.b.high + ids.carry_low
        ids.carry_high = 1 if sum_high >= ids.SHIFT else 0
    %}

    if (carry_low != 0) {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1 - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    } else {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    }
}

// Subtracts two integers. Returns the result as a 256-bit integer.
// Strictly equivalent and faster version of common.uint256.uint256_sub using uint256_add's whitelisted hint.
func uint256_sub{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256) {
    alloc_locals;
    // Reference "b" as -b.
    local b: Uint256 = Uint256(ALL_ONES - b.low + 1, ALL_ONES - b.high);
    // Computes a + (-b)
    local carry_low: felt;
    local carry_high: felt;
    %{
        sum_low = ids.a.low + ids.b.low
        ids.carry_low = 1 if sum_low >= ids.SHIFT else 0
        sum_high = ids.a.high + ids.b.high + ids.carry_low
        ids.carry_high = 1 if sum_high >= ids.SHIFT else 0
    %}

    if (carry_low != 0) {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1 - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        }
    } else {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        }
    }
}

// Write the elements of the array as key in the dictionary and assign the value 0 to each key.
// Used to check that an element in the dict is present by checking dict[key] == 1.
// Use with a default_dict with default_value = 0.
// If the element is present, the value will be 1.
// If the element is not present, the value will be 0.
func write_felt_array_to_dict_keys{dict_end: DictAccess*}(array: felt*, index: felt) {
    if (index == -1) {
        return ();
    } else {
        dict_write{dict_ptr=dict_end}(key=array[index], new_value=1);
        return write_felt_array_to_dict_keys(array, index - 1);
    }
}

// Write the elements of the array as key in the dictionary and assign the value 0 to each key.
// Used to check that an element in the dict is present by checking dict[key] == 1.
// Use with a default_dict with default_value = 0.
// If the element is present, the value will be 1.
// If the element is not present, the value will be 0.
func write_uint256_array_to_dict_keys{dict_end: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(array: Uint256*, index: felt) {
    if (index == -1) {
        return ();
    } else {
        let (key) = poseidon_hash(x=array[index].low, y=array[index].high);
        dict_write{dict_ptr=dict_end}(key=key, new_value=1);
        return write_uint256_array_to_dict_keys(array, index - 1);
    }
}

// Returns the number of bits in x.
// Implicits arguments:
// - pow2_array: felt* - A pointer such that pow2_array[i] = 2^i for i in [0, 127].
// Params:
// - x: felt - Input value.
// Assumptions for the caller:
// - 0 <= x < 2^127
// Returns:
// - bit_length: felt - Number of bits in x.
func get_felt_bitlength{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    if (x == 0) {
        return 0;
    }
    alloc_locals;
    local bit_length;
    %{ ids.bit_length = ids.x.bit_length() %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits
    tempvar N = pow2_array[bit_length];
    tempvar n = pow2_array[bit_length - 1];
    assert [range_check_ptr] = bit_length;
    assert [range_check_ptr + 1] = 127 - bit_length;
    assert [range_check_ptr + 2] = N - x - 1;
    assert [range_check_ptr + 3] = x - n;
    tempvar range_check_ptr = range_check_ptr + 4;
    return bit_length;
}

// Returns the number of bits in x.
// Implicits arguments:
// - pow2_array: felt* - A pointer such that pow2_array[i] = 2^i for i in [0, 128].
// Params:
// - x: felt - Input value.
// Assumptions for the caller:
// - 0 <= x < 2^128
// Returns:
// - bit_length: felt - Number of bits in x.
func get_felt_bitlength_128{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    if (x == 0) {
        return 0;
    }
    alloc_locals;
    local bit_length;
    %{ ids.bit_length = ids.x.bit_length() %}

    if (bit_length == 128) {
        assert [range_check_ptr] = x - 2 ** 127;
        tempvar range_check_ptr = range_check_ptr + 1;
        return bit_length;
    } else {
        // Computes N=2^bit_length and n=2^(bit_length-1)
        // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits
        tempvar N = pow2_array[bit_length];
        tempvar n = pow2_array[bit_length - 1];
        assert [range_check_ptr] = bit_length;
        assert [range_check_ptr + 1] = 128 - bit_length;
        assert [range_check_ptr + 2] = N - x - 1;
        assert [range_check_ptr + 3] = x - n;
        tempvar range_check_ptr = range_check_ptr + 4;
        return bit_length;
    }
}

// Computes x//y and x%y.
// Assumption: y must be a power of 2
// params:
//   x: the dividend.
//   y: the divisor.
// returns:
//   q: the quotient.
//   r: the remainder.
func bitwise_divmod{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (q: felt, r: felt) {
    if (y == 1) {
        let bitwise_ptr = bitwise_ptr;
        return (q=x, r=0);
    } else {
        assert bitwise_ptr.x = x;
        assert bitwise_ptr.y = y - 1;
        let x_and_y = bitwise_ptr.x_and_y;

        let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return (q=(x - x_and_y) / y, r=x_and_y);
    }
}

// Computes x//(2**32) and x%(2**32) using range checks operations.
// Adapted version of starkware.common.math.unsigned_div_rem with a fixed divisor of 2**32.
// Assumption : value / 2**32 < RC_BOUND
// params:
//   x: the dividend.
// returns:
//   q: the quotient .
//   r: the remainder.
func felt_divmod_2pow32{range_check_ptr}(value: felt) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.DIV_32)
        if not (0 < ids.DIV_32 <= PRIME):
            raise ValueError(f'div={hex(ids.DIV_32)} is out of the valid range.')
    %}
    %{ ids.q, ids.r = divmod(ids.value, ids.DIV_32) %}
    assert [range_check_ptr + 2] = DIV_32_MINUS_1 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * DIV_32 + r;
    return (q, r);
}

// Computes x//8 and x%8 using range checks operations.
// Adapted version of starkware.common.math.unsigned_div_rem with a fixed divisor of 2**32.
// Assumption : value / 8 < RC_BOUND
// params:
//   x: the dividend.
// returns:
//   q: the quotient .
//   r: the remainder.
func felt_divmod_8{range_check_ptr}(value: felt) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{ ids.q, ids.r = divmod(ids.value, 8) %}
    assert [range_check_ptr + 2] = 7 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * 8 + r;
    return (q, r);
}

// Returns q and r such that:
//  0 <= q < rc_bound, 0 <= r < div and value = q * div + r.
//
// Assumption: 0 < div <= PRIME / rc_bound.
// Prover assumption: value / div < rc_bound.
// Modified version of unsigned_div_rem with inlined range checks.
func felt_divmod{range_check_ptr}(value, div) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.div)
        if not (0 < ids.div <= PRIME):
            raise ValueError(f'div={hex(ids.div)} is out of the valid range.')
    %}
    %{ ids.q, ids.r = divmod(ids.value, ids.div) %}
    assert [range_check_ptr + 2] = div - 1 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * div + r;
    return (q, r);
}

// A function to reverse the byte endianness of a 8 bytes (64 bits) integer.
// The result will not make sense if word >= 2^64.
// The implementation is directly inspired by the function word_reverse_endian
// from the common library starkware.cairo.common.uint256 with three steps instead of four.
// params:
//   word: the 64 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_64{bitwise_ptr: BitwiseBuiltin*}(word: felt) -> (res: felt) {
    // Step 1.
    assert bitwise_ptr[0].x = word;
    assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff;
    tempvar word = word + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
    // Step 2.
    assert bitwise_ptr[1].x = word;
    assert bitwise_ptr[1].y = 0x0000ffff0000ffff00;
    tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
    // Step 3.
    assert bitwise_ptr[2].x = word;
    assert bitwise_ptr[2].y = 0x00000000ffffffff000000;
    tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;

    let bitwise_ptr = bitwise_ptr + 3 * BitwiseBuiltin.SIZE;
    return (res=word / 2 ** (8 + 16 + 32));
}

// A function to reverse the byte endianness of a 2 bytes (16 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^16.
// params:
//   word: the 16 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_16_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 2, memory, ap)
    %}
    ap += 2;

    let b0 = [ap - 2];
    let b1 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = b0;
    assert [range_check_ptr + 3] = b1;

    assert word = b0 * 256 + b1;

    tempvar range_check_ptr = range_check_ptr + 4;
    return b0 + b1 * 256;
}

// A function to reverse the byte endianness of a 3 bytes (24 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^24.
// params:
//   word: the 24 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_24_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 3, memory, ap)
    %}
    ap += 3;

    let b0 = [ap - 3];
    let b1 = [ap - 2];
    let b2 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = b0;
    assert [range_check_ptr + 4] = b1;
    assert [range_check_ptr + 5] = b2;

    assert word = b0 * 256 ** 2 + b1 * 256 + b2;

    tempvar range_check_ptr = range_check_ptr + 6;
    return b0 + b1 * 256 + b2 * 256 ** 2;
}

// A function to reverse the byte endianness of a 4 bytes (32 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^32.
// params:
//   word: the 32 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_32_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 4, memory, ap)
    %}
    ap += 4;

    let b0 = [ap - 4];
    let b1 = [ap - 3];
    let b2 = [ap - 2];
    let b3 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = b0;
    assert [range_check_ptr + 5] = b1;
    assert [range_check_ptr + 6] = b2;
    assert [range_check_ptr + 7] = b3;

    assert word = b0 * 256 ** 3 + b1 * 256 ** 2 + b2 * 256 + b3;

    tempvar range_check_ptr = range_check_ptr + 8;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3;
}

// A function to reverse the byte endianness of a 5 bytes (40 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^40.
// params:
//   word: the 40 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_40_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 5, memory, ap)
    %}
    ap += 5;

    let b0 = [ap - 5];
    let b1 = [ap - 4];
    let b2 = [ap - 3];
    let b3 = [ap - 2];
    let b4 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = b0;
    assert [range_check_ptr + 6] = b1;
    assert [range_check_ptr + 7] = b2;
    assert [range_check_ptr + 8] = b3;
    assert [range_check_ptr + 9] = b4;

    assert word = b0 * 256 ** 4 + b1 * 256 ** 3 + b2 * 256 ** 2 + b3 * 256 + b4;

    tempvar range_check_ptr = range_check_ptr + 10;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4;
}

// A function to reverse the byte endianness of a 6 bytes (48 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^48.
// params:
//   word: the 48 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_48_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 6, memory, ap)
    %}
    ap += 6;

    let b0 = [ap - 6];
    let b1 = [ap - 5];
    let b2 = [ap - 4];
    let b3 = [ap - 3];
    let b4 = [ap - 2];
    let b5 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = 255 - b5;
    assert [range_check_ptr + 6] = b0;
    assert [range_check_ptr + 7] = b1;
    assert [range_check_ptr + 8] = b2;
    assert [range_check_ptr + 9] = b3;
    assert [range_check_ptr + 10] = b4;
    assert [range_check_ptr + 11] = b5;

    assert word = b0 * 256 ** 5 + b1 * 256 ** 4 + b2 * 256 ** 3 + b3 * 256 ** 2 + b4 * 256 + b5;

    tempvar range_check_ptr = range_check_ptr + 12;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4 + b5 * 256 ** 5;
}

// A function to reverse the byte endianness of a 7 bytes (56 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^56.
// params:
//   word: the 56 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_56_RC{range_check_ptr}(word: felt) -> felt {
    %{
        from tools.py.hints import write_word_to_memory
        write_word_to_memory(ids.word, 7, memory, ap)
    %}
    ap += 7;

    let b0 = [ap - 7];
    let b1 = [ap - 6];
    let b2 = [ap - 5];
    let b3 = [ap - 4];
    let b4 = [ap - 3];
    let b5 = [ap - 2];
    let b6 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = 255 - b5;
    assert [range_check_ptr + 6] = 255 - b6;
    assert [range_check_ptr + 7] = b0;
    assert [range_check_ptr + 8] = b1;
    assert [range_check_ptr + 9] = b2;
    assert [range_check_ptr + 10] = b3;
    assert [range_check_ptr + 11] = b4;
    assert [range_check_ptr + 12] = b5;
    assert [range_check_ptr + 13] = b6;

    assert word = b0 * 256 ** 6 + b1 * 256 ** 5 + b2 * 256 ** 4 + b3 * 256 ** 3 + b4 * 256 ** 2 +
        b5 * 256 + b6;

    tempvar range_check_ptr = range_check_ptr + 14;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4 + b5 * 256 ** 5 + b6 *
        256 ** 6;
}

func get_0xff_mask(n: felt) -> felt {
    let (_, pc) = get_fp_and_pc();

    pc_labelx:
    let data = pc + (n_0xff - pc_labelx);

    let res = [data + n];

    return res;

    n_0xff:
    dw 0;
    dw 0xff;
    dw 0xffff;
    dw 0xffffff;
    dw 0xffffffff;
    dw 0xffffffffff;
    dw 0xffffffffffff;
    dw 0xffffffffffffff;
    dw 0xffffffffffffffff;
}

// Utility to get a pointer on an array of 2^i from i = 0 to 127.
func pow2alloc127() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
}

// Utility to get a pointer on an array of 2^i from i = 0 to 128.
func pow2alloc128() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
    dw 0x100000000000000000000000000000000;
}

func pow2alloc251() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
    dw 0x100000000000000000000000000000000;
    dw 0x200000000000000000000000000000000;
    dw 0x400000000000000000000000000000000;
    dw 0x800000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000000000;
}
