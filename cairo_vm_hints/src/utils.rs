use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, get_relocatable_from_var_name, insert_value_from_var_name},
    },
    types::relocatable::MaybeRelocatable,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;

pub fn split_u256(number: &BigUint) -> [BigUint; 2] {
    let mut iter = number.to_bytes_le().into_iter();
    let low = &iter.by_ref().take(16).collect::<Vec<_>>();
    let high = &iter.collect::<Vec<_>>();
    [BigUint::from_bytes_le(low), BigUint::from_bytes_le(high)]
}

pub fn write_value(
    var_name: &str,
    value: impl Into<MaybeRelocatable>,
    vm: &mut VirtualMachine,
    hint_data: &HintProcessorData,
) -> Result<(), HintError> {
    insert_value_from_var_name(var_name, value, vm, &hint_data.ids_data, &hint_data.ap_tracking)
}

pub fn write_struct(
    var_name: &str,
    values: &[MaybeRelocatable],
    vm: &mut VirtualMachine,
    hint_data: &HintProcessorData,
) -> Result<(), HintError> {
    vm.segments.load_data(
        get_relocatable_from_var_name(var_name, vm, &hint_data.ids_data, &hint_data.ap_tracking)?,
        values,
    )?;
    Ok(())
}

pub fn write_vector(
    var_name: &str,
    vector: &[MaybeRelocatable],
    vm: &mut VirtualMachine,
    hint_data: &HintProcessorData,
) -> Result<(), HintError> {
    vm.segments.load_data(
        get_ptr_from_var_name(var_name, vm, &hint_data.ids_data, &hint_data.ap_tracking)?,
        vector,
    )?;
    Ok(())
}

pub fn get_value(var_name: &str, vm: &mut VirtualMachine, hint_data: &HintProcessorData) -> Result<Felt252, HintError> {
    get_integer_from_var_name(var_name, vm, &hint_data.ids_data, &hint_data.ap_tracking)
}
