pub mod construct_mmr;
pub mod dw_hack;
pub mod encode_packed_256;
pub mod is_valid_mmr_size;

use crate::ExtendedHintProcessor;
use cairo_vm::{
    cairo_run,
    vm::{errors::cairo_run_errors::CairoRunError, runners::cairo_runner::CairoRunner},
};

pub fn run_cairo_program(program_content: &[u8]) -> Result<CairoRunner, CairoRunError> {
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: cairo_vm::types::layout_name::LayoutName::all_cairo,
        allow_missing_builtins: Some(true),
        ..Default::default()
    };

    Ok(cairo_run::cairo_run(
        program_content,
        &cairo_run_config,
        &mut ExtendedHintProcessor::new(),
    )?)
}
