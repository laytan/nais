#+private
package nais

foreign import js "nais"

import "core:encoding/base64"
import "core:log"

@(default_calling_convention="contextless")
foreign js {
	@(link_name="persist_get")
	__persist_get :: proc(dst: []byte, key: string) -> int ---

	@(link_name="persist_set")
	__persist_set :: proc(key: string, val: []byte) ---
}

_persist_get :: proc(key: string, allocator := context.allocator) -> (val: []byte, ok: bool) {
	length := __persist_get(nil, key)
	if length < 0 {
		return
	} else if length == 0 {
		ok = true
		return
	} else {
		buf, alloc_err := make([]byte, length, context.temp_allocator)
		assert(alloc_err == nil)

		res := __persist_get(buf, key)
		assert(len(buf) == res)

		decoded, err := base64.decode(string(buf), allocator=allocator)
		assert(err == nil)
		return decoded, true
	}
}

_persist_set :: proc(key: string, val: []byte) -> bool {
	encoded, err := base64.encode(val, allocator=context.temp_allocator)
	assert(err == nil)

	__persist_set(key, transmute([]byte)encoded)
	return true
}
