#+build !js
#+private
package nais

import    "core:log"
import    "core:path/filepath"
import os "core:os/os2"

_persist_get :: proc(key: string, allocator := context.allocator) -> (val: []byte, ok: bool) {
	path, path_err := filepath.join({__persist_dir(), key}, context.temp_allocator)
	assert(path_err == nil)

	data, err := os.read_entire_file(path, allocator)
	if err != nil {
		log.errorf("[nais]: reading file %q: %v", path, os.error_string(err))
		return
	}

	return data, true
}

_persist_set :: proc(key: string, val: []byte) -> bool {
	path, path_err := filepath.join({__persist_dir(), key}, context.temp_allocator)
	assert(path_err == nil)

	if err := os.write_entire_file(path, val); err != nil {
		log.errorf("[nais]: writing file %q: %v", path, os.error_string(err))
		return false
	}

	return true
}

@(private="file")
__persist_dir :: proc() -> string {
	@(static) cached: string
	if cached == "" {
		info, err := os.current_process_info({ .Executable_Path }, context.temp_allocator)
		if err != nil {
			log.errorf("[nais]: retrieving executable path via process info: %v", os.error_string(err))
			cached = ".nais"
		} else if info.executable_path == "" {
			log.errorf("[nais]: got empty executable path via process info")
			cached = ".nais"
		} else {
			cached = filepath.join({filepath.dir(info.executable_path, context.temp_allocator), ".nais"}, os.heap_allocator())
		}

		if mkerr := os.mkdir(cached); mkerr != nil && mkerr != .Exist {
			log.errorf("[nais]: creating directory %q: %v", cached, os.error_string(mkerr))
		}
	}

	assert(cached != "")
	return cached
}
