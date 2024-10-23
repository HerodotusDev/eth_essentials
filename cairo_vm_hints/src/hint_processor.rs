use crate::hints::{
    bit_length_mmr::{bit_length_mmr, BIT_LENGTH_MMR},
    bit_length_x::{bit_length_x, BIT_LENGTH_X},
    mmr_left_child::{mmr_left_child, MMR_LEFT_CHILD},
    test_construct_mmr::{test_construct_mmr, TEST_CONSTRUCT_MMR},
    test_is_valid_mmr_size_generate_random::{
        test_is_valid_mmr_size_generate_random, TEST_IS_VALID_MMR_SIZE_GENERATE_RANDOM,
    },
    test_is_valid_mmr_size_generate_sequential::{
        test_is_valid_mmr_size_generate_sequential, TEST_IS_VALID_MMR_SIZE_GENERATE_SEQUENTIAL,
    },
    test_is_valid_mmr_size_print_1::{
        test_is_valid_mmr_size_print_1, TEST_IS_VALID_MMR_SIZE_PRINT_1,
    },
    test_is_valid_mmr_size_print_2::{
        test_is_valid_mmr_size_print_2, TEST_IS_VALID_MMR_SIZE_PRINT_2,
    },
};
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
        TEST_IS_VALID_MMR_SIZE_PRINT_1 => {
            test_is_valid_mmr_size_print_1(vm, exec_scope, hint_data, constants)
        }
        TEST_IS_VALID_MMR_SIZE_PRINT_2 => {
            test_is_valid_mmr_size_print_2(vm, exec_scope, hint_data, constants)
        }
        TEST_IS_VALID_MMR_SIZE_GENERATE_SEQUENTIAL => {
            test_is_valid_mmr_size_generate_sequential(vm, exec_scope, hint_data, constants)
        }
        TEST_IS_VALID_MMR_SIZE_GENERATE_RANDOM => {
            test_is_valid_mmr_size_generate_random(vm, exec_scope, hint_data, constants)
        }
        BIT_LENGTH_X => bit_length_x(vm, exec_scope, hint_data, constants),
        BIT_LENGTH_MMR => bit_length_mmr(vm, exec_scope, hint_data, constants),
        TEST_CONSTRUCT_MMR => test_construct_mmr(vm, exec_scope, hint_data, constants),
        MMR_LEFT_CHILD => mmr_left_child(vm, exec_scope, hint_data, constants),
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
