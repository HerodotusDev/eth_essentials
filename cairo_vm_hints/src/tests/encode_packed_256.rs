use super::run_cairo_program;

#[test]
fn test() {
    let cairo_runner = run_cairo_program(include_bytes!(
        "../../../build/compiled_cairo_files/encode_packed_256_256_test.json"
    ))
    .unwrap();

    let execution_resources = cairo_runner.get_execution_resources().unwrap();
    println!("n_steps: {}", execution_resources.n_steps)
}
