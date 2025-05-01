package nais

import "core:log"
import "core:math"
import "core:math/linalg"

draw_circle :: proc(position: [2]f32, radius: f32, color: [4]f32) {
	// log.info(#procedure, position, radius, color)
	_draw_circle_sdf(position, radius, color)
}

draw_circle_outline :: proc(position: [2]f32, radius: f32, color: [4]f32, thickness: f32) {
	// log.info(#procedure, position, radius, color, thickness)
	_draw_circle_outline_sdf(position, radius, color, thickness)
}

/*
position: the top left position
size: the total size expanding from position
rounding: rounding applied to each corner top left, top right, bottom right, bottom left
angle: rotation (radians)
*/
draw_rectangle :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32 = 0, angle: f32 = 0) {
	_draw_rectangle_sdf(position, size, color, rounding, angle)
}

draw_rectangle_outline :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32, thickness: [4]f32) {
	// log.info(#procedure, position, size, color, rounding, thickness)
	_draw_rectangle_outline_sdf(position, size, color, rounding, thickness)
}

/*
p1: the first position of the line
p2: the second position of the line
thickness: the thickness (total) to apply, thickness * .5 is applied to both sides of the points given
*/
draw_segment :: proc(p1, p2: [2]f32, color: [4]f32, thickness: f32) {
	// TODO: make this work
	// dir    := p2 - p1
	// length := linalg.length(dir)
	// angle  := math.atan2(dir.y, dir.x)
	// norm   := dir / length
	// off    := [2]f32{-norm.y * thickness * .5, norm.x * thickness * .5}
	// pos    := [2]f32{(p1.x + p2.x) * .5 + off.x, (p1.y + p2.y) * .5 + off.y}
	// size   := [2]f32{length, thickness}
	// draw_rectangle(pos, size, color, 0, angle)

	_draw_segment_sdf(p1, p2, color, thickness)
}

draw_capsule :: proc(p1, p2: [2]f32, color: [4]f32, radius: f32) {
	// log.info(#procedure, p1, p2, radius, color)
	// draw_rectangle({p1.x-radius, p1.y}, {radius*2, p2.y-p1.y}, color, 0, ) // TODO:
	_draw_capsule_sdf(p1, p2, color, radius) // TODO: should radius be inside radius instead?
}

draw_capsule_outline :: proc(p1, p2: [2]f32, color: [4]f32, radius: f32, thickness: f32) {
	// log.info(#procedure, p1, p2, radius, color, thickness)
	draw_rectangle_outline({p1.x-radius, p1.y}, {radius*2, p2.y-p1.y}, color, 0, thickness) // TODO:
	// _draw_capsule_sdf(p1, p2, color, radius) // TODO
}
