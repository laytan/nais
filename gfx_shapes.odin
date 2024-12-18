package nais

draw_rectangle :: proc(position: [2]f32, size: [2]f32, color: u32, anchor: [2]f32 = 0, rotation: f32 = 0, flush := true) {
	// TODO: if sprite renderer is active, use that, if shape active, use that

	draw_sprite(Sprite(0), position, anchor, size, rotation, color, flush)
}

draw_triangle :: proc(points: [3][2]f32, color: u32) {
	_draw_triangle(points, color)
}

draw_triangle_strip :: proc(points: [][2]f32, color: u32) {
	_draw_triangle_strip(points, color)
}

draw_line :: proc(start, end: [2]f32, thick: f32, color: u32) {
	_draw_line(start, end, thick, color)
}

// TODO: take 2 vec2s instead of a rect struct, position and size.
draw_rectangle_rounded :: proc(rec: Rect, roundness: f32, segments: int, color: u32) {
	_draw_rectangle_rounded(rec, roundness, segments, color)
}

draw_circle_sector :: proc(center: [2]f32, radius, start_angle, end_angle: f32, segments: int, color: u32) {
	_draw_circle_sector(center, radius, start_angle, end_angle, segments, color)
}

draw_ring :: proc(center: [2]f32, inner_radius, outer_radius, start_angle, end_angle: f32, segments: int, color: u32) {
	_draw_ring(center, inner_radius, outer_radius, start_angle, end_angle, segments, color)
}

// Pixel
// Line
// LineBezier
// Circle
// CircleOutline
// Ellipse
// EllipseOutline
// Rectangle
// RectangleOutline
// RectangleRounded
// RectangleRoundedOutline
// Triangle
// TriangleOutline
// TriangleFan
// TriangleStrip
// Polygon
// PolygonOutline
// Spline etc.
