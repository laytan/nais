package nais

draw_circle :: proc(position: [2]f32, radius: f32, color: [4]f32) {
	_draw_circle_sdf(position, radius, color)
}

draw_rectangle :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32) {
	_draw_rectangle_sdf(position, size, color, rounding)
}

draw_rectangle_outline :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32, thickness: [4]f32) {
	_draw_rectangle_outline_sdf(position, size, color, rounding, thickness)
}
