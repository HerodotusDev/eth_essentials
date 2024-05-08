#!/bin/bash

# Activate virtual environment
source venv/bin/activate

# Define a boolean argument
IS_CI_RUN=false

for arg in "$@"
do
    if [ "$arg" == "--ci" ]
    then
        IS_CI_RUN=true
    fi
done

# Get the Cairo file from the command line argument
cairo_file="$1"
filename=$(basename "$cairo_file" .cairo)

echo "Running fuzzer for $filename"

# Define the log file path incorporating the filename
LOG_FILE="test_results_${filename}.log"

# Ensure the log file exists, otherwise create it
touch "$LOG_FILE"

# Export the log file path to be available in subshells
export LOG_FILE
export filenname

process_input() {
    local input_file="$2"
    local filename="$1"
    local batchname=$(basename "$input_file" .json)
    local temp_output=$(mktemp)


    # Attempt to run the compiled program and capture output
    local start_time=$(date +%s)
    cairo-run --program="build/compiled_cairo_files/$filename.json" --program_input=$input_file --layout=starknet_with_keccak >> "$temp_output" 2>&1
    local status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Handle output based on success or failure
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successful $input_file: Duration ${duration} seconds"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed: $input_file"
        cat "$temp_output"  # Output the error to the console
    fi

    cat "$temp_output" >> "$LOG_FILE"
    rm -f "$temp_output" # Clean up temporary file
    return $status
}

export -f process_input

# Ensure the Cairo file is compiled before running parallel tests
cairo-compile --cairo_path="packages/eth_essentials" "$cairo_file" --output "build/compiled_cairo_files/$filename.json"
# cairo-run --program="build/compiled_cairo_files/$filename.json" --program_input=tests/fuzzing/fixtures/mpt_proofs_5.json --layout=starknet_with_keccak
# Use --halt now,fail=1 to return non-zero if any task fails
find ./tests/fuzzing/fixtures -name "*.json" | parallel --halt now,fail=1 process_input $filename

# Clone the repository if the directory doesn't exist
if [ ! -d "mpt-fixtures" ]; then
    git clone https://github.com/HerodotusDev/mpt-fixtures
fi

echo "Starting tests..."
if $IS_CI_RUN; then
    # Run the tests in parallel
    find ./mpt-fixtures/fixtures/resolved -name "*.json" | parallel --halt soon,fail=1 process_input $filename
else
    # Run the tests in parallel
    find ./mpt-fixtures/fixtures/autogen -name "*.json" | parallel process_input $filename
fi

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
