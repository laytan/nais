package build

import    "core:fmt"
import    "core:http"
import    "core:log"
import    "core:strings"
import os "core:os/os2"

main :: proc() {
	level: log.Level = .Debug when ODIN_DEBUG else .Info
	opts: log.Options = {
		.Level,
		.Terminal_Color,
	}
	when ODIN_DEBUG {
		opts += {.Short_File_Path, .Line}
	}
	context.logger = log.create_console_logger(level, opts)

	if !build() {
		os.exit(1)
	}
}

INITIAL_MEMORY_PAGES :: 2000
MAX_MEMORY_PAGES     :: 65536

PAGE_SIZE :: 65536

build :: proc() -> bool {
	extra_linker_flags := fmt.tprintf(
		`-extra-linker-flags:"--export-table --import-memory --initial-memory=%v --max-memory=%v"`,
		INITIAL_MEMORY_PAGES * PAGE_SIZE,
		MAX_MEMORY_PAGES     * PAGE_SIZE,
	)

	system(
		"odin", "build", ".",
		"-o:speed",
		"-target:js_wasm32",
		"-target-features:bulk-memory,simd128",
		"-out:web/module.wasm",
		extra_linker_flags,
	) or_return

	cp("web/wgpu.js", odin_path("vendor", "wgpu", "wgpu.js")            or_return) or_return
	cp("web/odin.js", odin_path("core", "sys", "wasm", "js", "odin.js") or_return) or_return
	cp("web/nais.js", "../../nais.js")                                             or_return

	if len(os.args) > 1 && os.args[1] == "serve" {
		serve() or_return
	}

	return true
}

@(require_results)
serve :: proc() -> bool {
	s: http.Server

	handler := http.handler(proc(ctx: ^http.Context) {
		http.respond_dir(ctx.res, "", "web", ctx.req.url.path)
	})

	log.infof("serving web at port %v", http.Default_Endpoint.port)
	err := http.listen_and_serve(&s, handler)

	if err != nil {
		log.errorf("serve: %v", err)
		return false
	}

	return true
}

@(require_results)
cp :: proc(dst, src: string, loc := #caller_location) -> bool {
	log.debugf("cp %v -> %v", src, dst, location=loc)
	err := os.copy_file(dst, src)
	if err != nil {
		log.errorf("cp %v -> %v: %v", src, dst, os.error_string(err), location=loc)
		return false
	}

	return true
}

@(require_results)
odin_path :: proc(paths: ..string) -> (path: string, ok: bool) {
	paths_ := make([]string, len(paths) + 1, context.temp_allocator)	
	paths_[0] = ODIN_ROOT
	copy(paths_[1:], paths)

	joined, err := os.join_path(paths_, context.temp_allocator)
	print_error("os", "join_path", err) or_return
	return joined, true
}

@(require_results)
system :: proc(command: ..string, loc := #caller_location) -> bool {
	joined := strings.join(command, " ", context.temp_allocator)
	log.debug("executing", joined, location=loc)

	process, err := os.process_start({
		command = command,
		stderr = os.stderr,
		stdout = os.stdout,
	})
	print_error(joined, "start", err, loc) or_return

	state, werr := os.process_wait(process)
	print_error(joined, "wait", werr, loc) or_return

	return print_state(joined, state, loc)
}

@(require_results)
print_error :: proc(cmd: string, action: string, err: os.Error, loc := #caller_location) -> bool {
	if err == nil {
		return true
	}

	log.errorf("%s: %s: %s", cmd, action, os.error_string(err), location=loc)
	return false
}

@(require_results)
print_state :: proc(cmd: string, state: os.Process_State, loc := #caller_location) -> bool {
	assert(state.exited)

	log.infof("%s: code %v in %v user %v system", cmd, state.exit_code, state.user_time, state.system_time, location=loc)

	return state.exit_code == 0 && state.success
}
