package build

import    "core:fmt"
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

	if !_main() {
		os.exit(1)
	}
}

_main :: proc() -> bool {

	assert(len(os.args) > 0)

	if len(os.args) > 2 {
		extra := os.args[min(len(os.args), 3):]
		switch os.args[2] {
		case "web":
			return web(os.args[1], extra)
		case "build":
			return build(os.args[1], extra)
		case "run":
			return run(os.args[1], extra)
		case "hot":
			return hot()
		}
	}

	fmt.eprintfln("usage: %v <path> web|build|run|hot <extra odin args>", os.args[0])
	return false

	// if len(os.args) > 1 && os.args[1] == "web" {
	// 	extra_linker_flags := fmt.tprintf(
	// 		`-extra-linker-flags:"--export-table --import-memory --initial-memory=%v --max-memory=%v"`,
	// 		INITIAL_MEMORY_PAGES * PAGE_SIZE,
	// 		MAX_MEMORY_PAGES     * PAGE_SIZE,
	// 	)
	//
	// 	system(
	// 		"odin", "build", ".",
	// 		"-collection:pkg=../../../pkg",
	// 		"-o:speed",
	// 		"-target:js_wasm32",
	// 		"-target-features:bulk-memory,simd128",
	// 		"-out:web/module.wasm",
	// 		extra_linker_flags,
	// 	) or_return
	//
	// 	cp("web/wgpu.js", odin_path("vendor", "wgpu", "wgpu.js")            or_return) or_return
	// 	cp("web/odin.js", odin_path("core", "sys", "wasm", "js", "odin.js") or_return) or_return
	// 	cp("web/nais.js", "../../nais.js")                                             or_return
	//
	// 	// if len(os.args) > 2 && os.args[2] == "serve" {
	// 	// 	serve() or_return
	// 	// }
	// } else if len(os.args) > 1 && os.args[1] == "build" {
	// 	command: [dynamic]string
	// 	append(&command, "odin", "build", ".", "-collection:pkg=../../../pkg")
	// 	if len(os.args) > 2 {
	// 		append(&command, ..os.args[2:])
	// 	}
	//
	// 	system(..command[:]) or_return
	// } else if len(os.args) > 1 && os.args[1] == "run" {
	// 	command: [dynamic]string
	// 	append(&command, "odin", "run", ".", "-collection:pkg=../../../pkg")
	// 	if len(os.args) > 2 {
	// 		append(&command, ..os.args[2:])
	// 	}
	//
	// 	system(..command[:]) or_return
	// } else if len(os.args) > 1 && os.args[1] == "hot" {
	//
	// 	build_and_run :: proc() -> (p: os.Process, ok: bool) {
	// 		system("odin", "build", ".", "-collection:pkg=../../../pkg") or_return
	//
	// 		// TODO: use -out to make sure where it is.
	//
	// 		err: os.Error
	// 		p, err = os.process_start({
	// 			command = {"./imgui"},
	// 			stdout  = os.stdout,
	// 			stderr  = os.stderr,
	// 		})
	// 		ok = print_error("./imgui", "", err)
	// 		return
	// 	}
	//
	// 	filter :: proc(info: os.File_Info) -> bool {
	// 		_, name := os.split_path(info.fullpath)
	//
	// 		#partial switch info.type {
	// 		case .Directory:
	// 			switch name {
	// 			case ".git", "examples": return false
	// 			case:                    return true
	// 			}
	// 		case .Regular:
	// 			_, ext := os.split_filename(name)
	// 			switch ext {
	// 			case "odin", "a", "lib", "dylib", "dll", "o", "wgsl": return true
	// 			case:                                                 return false
	// 			}
	// 		case:
	// 			return false
	// 		}
	// 	}
	//
	// 	p := build_and_run() or_return
	//
	// 	prev_digest: u64
	// 	hasher: Hasher_State
	// 	for {
	// 		defer time.sleep(time.Second)
	//
	// 		state, err := os.process_wait(p, 0)
	// 		if err != nil && err != .Timeout {
	// 			print_error("odin", "run", err) or_return
	// 		}
	//
	// 		if state.exited {
	// 			log.info("process exited")
	// 			return false
	// 		}
	//
	// 		{
	// 			digest: u64
	// 			d: time.Duration
	// 			{
	// 				time.SCOPED_TICK_DURATION(&d)
	// 				hash_reset(&hasher)
	// 				hash_dir(&hasher, ".",       filter) // example
	// 				hash_dir(&hasher, "../..",   filter) // nais
	// 				// hash_dir(&hasher, ODIN_ROOT, filter) // Odin
	// 				digest = hash_digest(&hasher)
	// 			}
	//
	// 			log.info(d)
	//
	// 			if prev_digest != 0 && prev_digest != digest {
	// 				log.info("restart!")
	//
	// 				err := os.process_kill(p)
	// 				print_error("odin", "kill", err) or_return
	// 				
	// 				state, err = os.process_wait(p)
	// 				_ = print_error("odin", "wait", err)
	// 				assert(err != nil || state.exited)
	//
	// 				p = build_and_run() or_return
	// 			}
	// 			prev_digest = digest
	// 		}
	// 	}
	//
	//
	// } else {
	// 	fmt.eprintfln("usage: %v web|build|run <path> <extra odin args>", os.args[0])
	// }
	//
	// return true
}

web :: proc(path: string, extra_args: []string) -> bool {
	INITIAL_MEMORY_PAGES :: 2000
	MAX_MEMORY_PAGES     :: 65536

	PAGE_SIZE :: 65536

	_, name := os.split_path(path)
	out := out_dir(path) or_return
	web := join_path({out, "web"}) or_return
	mod := join_path({web, "module.wasm"}) or_return

	err := os.remove_all(web)
	if err != .Not_Exist {
		print_error("rmrf web", err) or_return
	}

	err = os.make_directory(web)
	if err != .Exist {
		print_error("mkdir web", err) or_return
	}

	command: [dynamic]string
	append(
		&command,
		"odin", "build", path,
		"-target:js_wasm32",
		fmt.tprintf(`-out:"%s"`, mod),
		fmt.tprintf(`-extra-linker-flags:"--export-table --import-memory --initial-memory=%v --max-memory=%v"`, INITIAL_MEMORY_PAGES * PAGE_SIZE, MAX_MEMORY_PAGES * PAGE_SIZE),
	)
	append(&command, ..extra_args)
	system(..command[:]) or_return

	nais := nais_dir() or_return
	cp(join_path({web, "wgpu.js"}) or_return, join_path({ODIN_ROOT, "vendor", "wgpu", "wgpu.js"}) or_return) or_return
	cp(join_path({web, "odin.js"}) or_return, join_path({ODIN_ROOT, "core", "sys", "wasm", "js", "odin.js"}) or_return) or_return
	cp(join_path({web, "nais.js"}) or_return, join_path({nais, "nais.js"}) or_return) or_return

	template, read_err := os.read_entire_file(join_path({build_dir(), "index.template.html"}) or_return, context.allocator)
	print_error("read index.template.html", read_err) or_return

	index := fmt.tprintf(string(template), name, INITIAL_MEMORY_PAGES, MAX_MEMORY_PAGES)
	write_err := os.write_entire_file(join_path({web, "index.html"}) or_return, transmute([]byte)index)
	print_error("write index.html", write_err) or_return

	return true
}

build :: proc(path: string, extra_args: []string) -> bool {
	_, name := os.split_path(path)
	out := join_path({out_dir(path) or_return, name}) or_return

	command: [dynamic]string
	append(
		&command,
		"odin", "build", path,
		fmt.tprintf(`-out:"%s"`, out),
	)
	append(&command, ..extra_args)
	system(..command[:]) or_return

	return true
}

run :: proc(path: string, extra_args: []string) -> bool {
	_, name := os.split_path(path)
	out := join_path({out_dir(path) or_return, name}) or_return

	command: [dynamic]string
	append(
		&command,
		"odin", "run", path,
		fmt.tprintf(`-out:"%s"`, out),
	)
	append(&command, ..extra_args)
	system(..command[:]) or_return

	return true
}

hot :: proc() -> bool {
	unimplemented("hot")
}

serve :: proc() -> bool {
	unimplemented("serve")
}

@(require_results)
join_path :: proc(paths: []string, loc := #caller_location) -> (_joined: string, ok: bool) {
	joined, err := os.join_path(paths, context.allocator)
	print_error("join_path", err, loc=loc) or_return
	return joined, true
}

@(require_results)
build_dir :: proc() -> string {
	build_dir, _  := os.split_path(#directory)
	return build_dir
}

@(require_results)
nais_dir :: proc(loc := #caller_location) -> (_nais_dir: string, ok: bool) {
	return join_path({build_dir(), "..", ".."}, loc=loc)
}

@(require_results)
out_dir :: proc(path: string, loc := #caller_location) -> (_out: string, ok: bool) {
	_, name := os.split_path(path)

	out := join_path({build_dir(), "..", "_out", name}, loc=loc) or_return

	err := os.make_directory_all(out)
	if err != .Exist {
		print_error("make_directory_all", err, loc=loc) or_return
	}

	return out, true
}


// @(require_results)
// serve :: proc() -> bool {
// 	s: http.Server
//
// 	handler := http.handler(proc(ctx: ^http.Context) {
// 		http.respond_dir(ctx.res, "", "web", ctx.req.url.path)
// 	})
//
// 	log.infof("serving web at port %v", http.Default_Endpoint.port)
// 	err := http.listen_and_serve(&s, handler)
//
// 	if err != nil {
// 		log.errorf("serve: %v", err)
// 		return false
// 	}
//
// 	return true
// }

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

// @(require_results)
// odin_path :: proc(paths: ..string) -> (path: string, ok: bool) {
// 	paths_ := make([]string, len(paths) + 1, context.temp_allocator)	
// 	paths_[0] = ODIN_ROOT
// 	copy(paths_[1:], paths)
//
// 	joined, err := os.join_path(paths_, context.temp_allocator)
// 	print_error("os", "join_path", err) or_return
// 	return joined, true
// }
//
@(require_results)
system :: proc(command: ..string, loc := #caller_location) -> bool {
	joined := strings.join(command, " ", context.temp_allocator)
	log.debug("executing", joined, location=loc)

	process, err := os.process_start({
		command = command,
		stderr = os.stderr,
		stdout = os.stdout,
	})
	print_cmd_error(joined, "start", err, loc) or_return

	state, werr := os.process_wait(process)
	print_cmd_error(joined, "wait", werr, loc) or_return

	return print_state(joined, state, loc)
}

@(require_results)
print_error :: proc(action: string, err: os.Error, loc := #caller_location) -> bool {
	if err == nil {
		return true
	}

	log.errorf("%s: %s", action, os.error_string(err), location=loc)
	return false
}

@(require_results)
print_cmd_error :: proc(cmd, action: string, err: os.Error, loc := #caller_location) -> bool {
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

//
// Hasher_State :: struct {
// 	hash:   xxhash.XXH3_state,
// 	walker: os.Walker,
// }
//
// hash_reset :: proc(state: ^Hasher_State) {
// 	xxhash.XXH3_64_reset(&state.hash)
// }
//
// hash_dir :: proc(state: ^Hasher_State, path: string, filter: proc(info: os.File_Info) -> bool) {
// 	os.walker_init_path(&state.walker, path)
//
// 	for info in os.walker_walk(&state.walker) {
// 		_ = os.walker_error(&state.walker) or_break
//
// 		(info.type == .Directory || info.type == .Regular) or_continue
//
// 		if !filter(info) {
// 			if info.type == .Directory {
// 				os.walker_skip_dir(&state.walker)
// 			}
// 			continue
// 		}
//
// 		if info.type == .Regular {
// 			log.debug(info.fullpath)
//
// 			mod := info.modification_time
// 			assert(mod._nsec > 0)
// 			bytes := ([^]byte)(&mod)[:size_of(mod)]
//
// 			xxhash.XXH3_64_update(&state.hash, bytes)
// 		}
// 	}
//
// 	if path, err := os.walker_error(&state.walker); err != nil {
// 		log.errorf("%q: %v", path, os.error_string(err))
// 	}
// }
//
// hash_digest :: proc(state: ^Hasher_State) -> u64 {
// 	return xxhash.XXH3_64_digest(&state.hash)
// }
