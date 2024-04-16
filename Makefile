.PHONY: build test coverage
cairo_files = $(shell find ./tests/cairo_programs -name "*.cairo")

build:
	$(MAKE) clean
	./tools/make/build.sh

setup:
	./tools/make/setup.sh

run-profile:
	@echo "A script to select, compile, run & profile one Cairo file"
	./tools/make/launch_cairo_files.py -profile

test:
	@echo "Run all tests in tests/cairo_programs" 
	./tools/make/launch_cairo_files.py -test

get-program-hash:
	@echo "Get chunk_processor.cairo program's hash."
	cairo-compile ./src/single_chunk_processor/chunk_processor.cairo --output build/compiled_cairo_files/chunk_processor.json
	cairo-hash-program --program build/compiled_cairo_files/chunk_processor.json
clean:
	rm -rf build/compiled_cairo_files
	mkdir -p build
	mkdir build/compiled_cairo_files

ci-local:
	./tools/make/ci_local.sh
	
test-full:
	./tools/make/cairo_tests.sh

format-cairo:
	@echo "Format all .cairo files"
	./tools/make/format_cairo_files.sh