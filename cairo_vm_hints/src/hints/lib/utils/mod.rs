use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

mod assert;
mod carry;
mod divmod;
mod trailing_zeroes;
mod write;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        assert::HINT_ASSERT_INTEGER_DIV32 => {
            assert::hint_assert_integer_div32(vm, exec_scope, hint_data, constants)
        }
        assert::HINT_ASSERT_INTEGER_DIV => {
            assert::hint_assert_integer_div(vm, exec_scope, hint_data, constants)
        }
        carry::HINT_CARRY => carry::hint_carry(vm, exec_scope, hint_data, constants),
        divmod::HINT_VALUE_DIV32 => divmod::hint_value_div32(vm, exec_scope, hint_data, constants),
        divmod::HINT_VALUE_8 => divmod::hint_value_8(vm, exec_scope, hint_data, constants),
        divmod::HINT_VALUE_DIV => divmod::hint_value_div(vm, exec_scope, hint_data, constants),
        trailing_zeroes::HINT_TRAILING_ZEROES_BYTES => {
            trailing_zeroes::hint_trailing_zeroes_bytes(vm, exec_scope, hint_data, constants)
        }
        write::HINT_WRITE_2 => write::hint_write_2(vm, exec_scope, hint_data, constants),
        write::HINT_WRITE_3 => write::hint_write_3(vm, exec_scope, hint_data, constants),
        write::HINT_WRITE_4 => write::hint_write_4(vm, exec_scope, hint_data, constants),
        write::HINT_WRITE_5 => write::hint_write_5(vm, exec_scope, hint_data, constants),
        write::HINT_WRITE_6 => write::hint_write_6(vm, exec_scope, hint_data, constants),
        write::HINT_WRITE_7 => write::hint_write_7(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
