%builtins output range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from lib.utils import pow2alloc128, uint256_reverse_endian_no_padding, Uint256

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (pow2_array: felt*) = pow2alloc128();
    // test_reverse(n_bits_index=1, pow2_array=pow2_array);
    // %{ print("End tests!") %}
    local x: Uint256;
    %{
        import random 
        random.seed(0)
        from tools.py.utils import split_128
        # Used for the sanity check
        def parse_int_to_bytes(x:int)-> bytes:
            hex_str = hex(x)[2:]
            if len(hex_str)%2==1:
                hex_str = '0'+hex_str
            return bytes.fromhex(hex_str)

        x = 0x5553adf1a587bc5465b321660008c4c2e825bd3df2d2ccf001a009f3
        input_bytes = parse_int_to_bytes(x)
        print(f"input: {input_bytes}")
        ids.x.low, ids.x.high = split_128(x)
        print(f"input : {hex(x)}_{x.bit_length()}b")
        print(f"input: {hex(ids.x.high)}_{ids.x.high.bit_length()}b {hex(ids.x.low)}_{ids.x.low.bit_length()}b")
    %}
    let (res, n_bytes) = uint256_reverse_endian_no_padding(x, pow2_array);
    %{
        # Test. 
        res_bytes = parse_int_to_bytes(ids.res.low + 2**128 * ids.res.high)
        print(f"output : {hex(ids.res.high)}_{ids.res.high.bit_length()}b {hex(ids.res.low)}_{ids.res.low.bit_length()}b")
        print(f"output: {res_bytes}")
        # The input and output bytes should be the same, reversed.
        assert input_bytes[::-1] == res_bytes, f"{input_bytes[::-1]} != {res_bytes}"
        # The number of bytes returned should be the same as the number of bytes in the input.
        assert ids.n_bytes == len(input_bytes)==len(res_bytes), f"{ids.n_bytes} != {len(input_bytes)} != {len(res_bytes)}"
    %}
    local x: Uint256;
    %{
        print("Second edge case")
        x = 0xb847b60dcb5d984fc2a1ca0040a550cd3c4ac0adef268ded1249e1ae
        input_bytes = parse_int_to_bytes(x)
        print(f"input: {input_bytes}")
        ids.x.low, ids.x.high = split_128(x)
        print(f"input : {hex(x)}_{x.bit_length()}b")
        print(f"input: {hex(ids.x.high)}_{ids.x.high.bit_length()}b {hex(ids.x.low)}_{ids.x.low.bit_length()}b")
    %}

    let (res, n_bytes) = uint256_reverse_endian_no_padding(x, pow2_array);
    %{
        # Test. 
        res_bytes = parse_int_to_bytes(ids.res.low + 2**128 * ids.res.high)
        print(f"output : {hex(ids.res.high)}_{ids.res.high.bit_length()}b {hex(ids.res.low)}_{ids.res.low.bit_length()}b")
        print(f"output: {res_bytes}")
        # The input and output bytes should be the same, reversed.
        assert input_bytes[::-1] == res_bytes, f"{input_bytes[::-1]} != {res_bytes}"
        # The number of bytes returned should be the same as the number of bytes in the input.
        assert ids.n_bytes == len(input_bytes)==len(res_bytes), f"{ids.n_bytes} != {len(input_bytes)} != {len(res_bytes)}"
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
        from tools.py.utils import split_128
        # Used for the sanity check
        def parse_int_to_bytes(x:int)-> bytes:
            hex_str = hex(x)[2:]
            if len(hex_str)%2==1:
                hex_str = '0'+hex_str
            return bytes.fromhex(hex_str)


        x = random.randint(2**(ids.n_bits_in_input - 1), 2**ids.n_bits_in_input - 1)
        input_bytes = parse_int_to_bytes(x)

        print(f"N bits in input: {ids.n_bits_in_input}")
        print(f"input: {input_bytes}")
        ids.x.low, ids.x.high = split_128(x)
        print(f"input: {hex(ids.x.low + 2**128 * ids.x.high)}")
    %}
    let (res, n_bytes) = uint256_reverse_endian_no_padding(x, pow2_array);
    %{
        # Test. 
        res_bytes = parse_int_to_bytes(ids.res.low + 2**128 * ids.res.high)
        print(f"output: {res_bytes}")
        # The input and output bytes should be the same, reversed.
        assert input_bytes[::-1] == res_bytes, f"{input_bytes[::-1]} != {res_bytes}"
        # The number of bytes returned should be the same as the number of bytes in the input.
        assert ids.n_bytes == len(input_bytes)==len(res_bytes), f"{ids.n_bytes} != {len(input_bytes)} != {len(res_bytes)}"
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
