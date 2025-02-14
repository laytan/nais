package main

import    "core:fmt"
import os "core:os/os2"
import    "core:strings"
import    "core:path/filepath"
import    "core:log"

main :: proc() {
	switch os.args[1] {
	case "web":
		INITIAL_MEMORY_PAGES :: 2000
		MAX_MEMORY_PAGES     :: 65536

		PAGE_SIZE :: 65536

		INITIAL_MEMORY_BYTES :: INITIAL_MEMORY_PAGES * PAGE_SIZE
		MAX_MEMORY_BYTES     :: MAX_MEMORY_PAGES * PAGE_SIZE

		root := odin_root()

		src := filepath.join({#directory, ".."})
		out := filepath.join({#directory, "..", "web", "jam.wasm"})

		state, stdout, stderr, err := os.process_exec({
			command = {
				"odin",
				"build",
				src,
				"-target:js_wasm32",
				strings.concatenate({"-out:", out}),
				fmt.aprintf("-extra-linker-flags:--export-table --import-memory --initial-memory=%v --max-memory=%v", INITIAL_MEMORY_BYTES, MAX_MEMORY_BYTES),
				"-target-features:bulk-memory,simd128",
				"-o:speed",

				// "-debug",
				// "-use-separate-modules",
			},
		}, context.allocator)
		check(state, err, string(stderr))

		err = os.copy_file(
			filepath.join({#directory, "..", "web", "wgpu.js"}),
			filepath.join({root, "vendor", "wgpu", "wgpu.js"}),
		)
		check(err, "cp wgpu.js")

		err = os.copy_file(
			filepath.join({#directory, "..", "web", "odin.js"}),
			filepath.join({root, "core", "sys", "wasm", "js", "odin.js"}),
		)
		check(err, "cp odin.js")

		err = os.copy_file(
			filepath.join({#directory, "..", "web", "nais.js"}),
			filepath.join({#directory, "..", "..", "..", "nais.js"}),
		)
		check(err, "cp nais.js")

	case "desktop":
		src := filepath.join({#directory, ".."})
		out := filepath.join({#directory, "..", "bin", "desktop"})

		p, err := os.process_start({
			command = {
				"odin",
				"run",
				src,
				strings.concatenate({"-out:", out}),

				"-debug",
				"-use-separate-modules",
			},
			stderr  = os.stderr,
			stdout  = os.stdout,
			stdin   = os.stdin,
		})
		check(err, "odin run")

		s, werr := os.process_wait(p)
		check(s, werr, "odin run wait")
	}
}

odin_root :: proc() -> string {
	state, stdout, stderr, err := os.process_exec({
		command = {"odin", "root"},
	}, context.allocator)
	check(state, err, string(stderr))
	return string(stdout)
}

check_state :: proc(state: os.Process_State, err: os.Error, msg: string = "", loc := #caller_location) {
	check_err(err, msg, loc)

	if !state.success {
		fmt.eprintln(loc.procedure if msg == "" else msg)
		os.exit(state.exit_code)
	}
}

check_err :: proc(err: os.Error, msg: string = "", loc := #caller_location) {
	if err != nil {
		os.print_error(os.stderr, err, loc.procedure if msg == "" else msg)
		os.exit(1)
	}
}

check :: proc {
	check_err,
	check_state,
}
