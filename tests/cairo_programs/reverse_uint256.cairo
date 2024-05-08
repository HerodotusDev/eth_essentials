%builtins output range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from lib.utils import pow2alloc128, uint256_reverse_endian_no_padding, Uint256

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (pow2_array: felt*) = pow2alloc128();

    // Some edge cases.
    local x1: Uint256;
    local x2: Uint256;
    local x3: Uint256;
    local x4: Uint256;
    local x5: Uint256;
    local x6: Uint256;
    local x7: Uint256;
    %{
        import random 
        random.seed(0)
        from tools.py.utils import split_128, parse_int_to_bytes, count_leading_zero_nibbles_from_hex

        x1 = 0x5553adf1a587bc5465b321660008c4c2e825bd3df2d2ccf001a009f3
        x2 = 0xb847b60dcb5d984fc2a1ca0040a550cd3c4ac0adef268ded1249e1ae
        x3 = 0xd4ae28bf208da8ad396463110021760d8278befbac8b4ecacb7c6e00
        x4 = 0x12345600
        x5 = 0x12401
        x6 = 0x1240100
        x7 = 0x124010

        ids.x1.low, ids.x1.high = split_128(x1)
        ids.x2.low, ids.x2.high = split_128(x2)
        ids.x3.low, ids.x3.high = split_128(x3)
        ids.x4.low, ids.x4.high = split_128(x4)
        ids.x5.low, ids.x5.high = split_128(x5)
        ids.x6.low, ids.x6.high = split_128(x6)
        ids.x7.low, ids.x7.high = split_128(x7)

        def test_function(test_input:int, test_output:int):
            input_bytes = parse_int_to_bytes(test_input)
            res_bytes = parse_int_to_bytes(test_output)

            print(f"test_input: {input_bytes}")
            print(f"test_output: {res_bytes}")

            expected_output = input_bytes[::-1] # Reverse the input bytes.
            # Trim leading zeroes from expected output : 
            expected_output = expected_output.lstrip(b'\x00')
            # The input and output bytes should be the same, reversed.
            assert expected_output == res_bytes, f"{expected_output} != {res_bytes}"
    %}

    test_reverse_single(x=x1, pow2_array=pow2_array);
    test_reverse_single(x=x2, pow2_array=pow2_array);
    test_reverse_single(x=x3, pow2_array=pow2_array);
    test_reverse_single(x=x4, pow2_array=pow2_array);
    test_reverse_single(x=x5, pow2_array=pow2_array);
    test_reverse_single(x=x6, pow2_array=pow2_array);
    test_reverse_single(x=x7, pow2_array=pow2_array);

    test_reverse(n_bits_index=1, pow2_array=pow2_array);

    %{ print("End tests!") %}

    return ();
}

func test_reverse_single{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    x: Uint256, pow2_array: felt*
) {
    alloc_locals;
    let (res, n_bytes) = uint256_reverse_endian_no_padding(x, pow2_array);
    %{
        # Test. 
        test_function(test_input=ids.x.low + 2**128*ids.x.high, test_output=ids.res.low+2**128*ids.res.high)
    %}
    return ();
}
func test_reverse_inner{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    n_bits_in_input: felt, pow2_array: felt*
) {
    alloc_locals;
    local x: Uint256;
    %{
        import random 
        random.seed(0)
        x = random.randint(2**(ids.n_bits_in_input - 1), 2**ids.n_bits_in_input - 1)
        ids.x.low, ids.x.high = split_128(x)
    %}
    let (res, n_bytes) = uint256_reverse_endian_no_padding(x, pow2_array);
    %{
        # Test. 
        test_function(test_input=ids.x.low + 2**128*ids.x.high, test_output=ids.res.low+2**128*ids.res.high)
    %}
    return ();
}

func test_reverse{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    n_bits_index: felt, pow2_array: felt*
) {
    alloc_locals;
    if (n_bits_index == 257) {
        return ();
    }
    test_reverse_inner(n_bits_in_input=n_bits_index, pow2_array=pow2_array);
    return test_reverse(n_bits_index=n_bits_index + 1, pow2_array=pow2_array);
}
