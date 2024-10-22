use crate::hints::lib;
use crate::hints::tests;
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{
            BuiltinHintProcessor, HintFunc, HintProcessorData,
        },
        hint_processor_definition::HintExtension,
        hint_processor_definition::HintProcessorLogic,
    },
    types::exec_scope::ExecutionScopes,
    vm::{
        errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker,
        vm_core::VirtualMachine,
    },
    Felt252,
};
use starknet_types_core::felt::Felt;
use std::collections::HashMap;
use std::{any::Any, rc::Rc};

#[derive(Default)]
pub struct CustomHintProcessor;

impl CustomHintProcessor {
    pub fn new() -> Self {
        Self {}
    }
}

fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        tests::print::HINT_PRINT_BREAKLINE => {
            tests::print::hint_print_breakline(vm, exec_scope, hint_data, constants)
        }
        tests::print::HINT_PRINT_PASS => {
            tests::print::hint_print_pass(vm, exec_scope, hint_data, constants)
        }
        tests::mmr_size_generate::HINT_GENERATE_SEQUENTIAL => {
            tests::mmr_size_generate::hint_generate_sequential(vm, exec_scope, hint_data, constants)
        }
        tests::mmr_size_generate::HINT_GENERATE_RANDOM => {
            tests::mmr_size_generate::hint_generate_random(vm, exec_scope, hint_data, constants)
        }
        lib::bit_length::HINT_BIT_LENGTH => {
            lib::bit_length::hint_bit_length(vm, exec_scope, hint_data, constants)
        }
        tests::dw_hack::HINT_BIT_LENGTH_ASSIGN_140 => {
            tests::dw_hack::hint_bit_length_assign_140(vm, exec_scope, hint_data, constants)
        }
        tests::dw_hack::HINT_BIT_LENGTH_ASSIGN_2500 => {
            tests::dw_hack::hint_bit_length_assign_2500(vm, exec_scope, hint_data, constants)
        }
        tests::dw_hack::HINT_BIT_LENGTH_ASSIGN_NEGATIVE_ONE => {
            tests::dw_hack::hint_bit_length_assign_negative_one(
                vm, exec_scope, hint_data, constants,
            )
        }
        tests::dw_hack::HINT_PRINT_NS => {
            tests::dw_hack::hint_print_ns(vm, exec_scope, hint_data, constants)
        }
        tests::encode_packed_256::HINT_GENERATE_TEST_VECTOR => {
            tests::encode_packed_256::hint_generate_test_vector(
                vm, exec_scope, hint_data, constants,
            )
        }
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}

impl HintProcessorLogic for CustomHintProcessor {
    fn execute_hint(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let hint_data = hint_data
            .downcast_ref::<HintProcessorData>()
            .ok_or(HintError::WrongHintData)?;

        run_hint(vm, exec_scopes, hint_data, constants)
    }
}

impl ResourceTracker for CustomHintProcessor {}

pub struct ExtendedHintProcessor {
    custom_hint_processor: CustomHintProcessor,
    builtin_hint_processor: BuiltinHintProcessor,
}

impl Default for ExtendedHintProcessor {
    fn default() -> Self {
        Self::new()
    }
}

impl ExtendedHintProcessor {
    pub fn new() -> Self {
        Self {
            custom_hint_processor: CustomHintProcessor {},
            builtin_hint_processor: BuiltinHintProcessor::new_empty(),
        }
    }

    pub fn add_hint(&mut self, hint_code: String, hint_func: Rc<HintFunc>) {
        self.builtin_hint_processor
            .extra_hints
            .insert(hint_code, hint_func);
    }
}

impl HintProcessorLogic for ExtendedHintProcessor {
    fn execute_hint(
        &mut self,
        _vm: &mut VirtualMachine,
        _exec_scopes: &mut ExecutionScopes,
        _hint_data: &Box<dyn Any>,
        _constants: &HashMap<String, Felt>,
    ) -> Result<(), HintError> {
        unreachable!();
    }

    fn execute_hint_extensive(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt>,
    ) -> Result<HintExtension, HintError> {
        match self.custom_hint_processor.execute_hint_extensive(
            vm,
            exec_scopes,
            hint_data,
            constants,
        ) {
            Err(HintError::UnknownHint(_)) => {}
            result => {
                return result;
            }
        }

        self.builtin_hint_processor
            .execute_hint_extensive(vm, exec_scopes, hint_data, constants)
    }
}

impl ResourceTracker for ExtendedHintProcessor {}
