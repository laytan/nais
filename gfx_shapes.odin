package nais

@(private)
_gfx_init_shapes :: proc() {
}
draw_rectangle :: proc(position: [2]f32, size: [2]f32, color: u32, anchor: [2]f32 = 0, rotation: f32 = 0, flush := true) {
	// TODO: if sprite renderer is active, use that

	draw_sprite(Sprite(0), position, anchor, size, rotation, color, flush)
}
