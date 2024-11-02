package nais

persist_get :: proc(key: string, allocator := context.allocator) -> (val: []byte, ok: bool) {
	return _persist_get(key, allocator)
}

persist_set :: proc(key: string, val: []byte) -> bool {
	return _persist_set(key, val)
}
