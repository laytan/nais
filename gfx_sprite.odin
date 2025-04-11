package nais

import "core:image"
import "core:image/png"
import "core:log"
import "core:slice"
import "core:bytes"

// Wants:
// - add and remove sprites at user's leasure
// - loading returns a pointer/handle in which we store location and size in sprite sheet
// - each change would rect pack and update the gpu texture
// - default rectangle sprite (could do some opts when this renderer is in use and a rectangle is requested, so we don't need to flush and switch to shapes renderer
// - loading a sprite in js has it's quirks

Sprite :: distinct int

Sprite_Data :: struct {
	anchor, position, scale: [2]f32,
	rotation: f32,
	color:    u32,
}

File_Type :: enum {
	None,
	PNG,
}

load_sprite_from_file :: proc(path: string) -> Sprite {
	// TODO: will be async in JS, need to return a temporary sprite (one of those missing texture sprites).
	// And have a callback too.
	unimplemented()
}

load_sprite_from_memory :: proc(data: []byte, type: File_Type) -> Sprite {
	switch type {
	case .PNG:
		img, err := png.load_from_bytes(data, {}, context.allocator)
		if err != nil {
			log.panicf("failed to parse PNG image: %v", err)
		}

		log.debugf("%#v", img)

		// Convert from RGBA to BGRA
		pixels := slice.reinterpret([]image.RGBA_Pixel, bytes.buffer_to_bytes(&img.pixels))
		for &pixel in pixels {
			pixel = pixel.bgra
		}

		return load_sprite_from_pixels(pixels, img.width)

	case .None: fallthrough
	case:
		log.panicf("invalid file type: %v", type)
	}
}

load_sprite_from_pixels :: proc(pixels: [][4]u8, width: int) -> Sprite {
	return _load_sprite_from_pixels(pixels, width)
}

unload_sprite :: proc(sprite: Sprite) {
	unimplemented()
}

@(require_results)
scale_sprite :: proc(sprite: Sprite, size: [2]f32) -> (scale: [2]f32) {
	return _scale_sprite(sprite, size)
}

// TODO: API to load an entire sprite sheet in, maybe?

draw_sprite :: proc(sprite: Sprite, position: [2]f32, anchor: [2]f32 = 0, scale: [2]f32 = 1, rotation: f32 = 0, color: u32 = 0xFFFFFFFF, flush := true) {
	draw_sprite_data(sprite, {
		anchor   = anchor,
		position = position,
		scale    = scale,
		rotation = rotation,
		color    = color,
	}, flush)
}

draw_sprite_data :: proc(sprite: Sprite, data: Sprite_Data, flush := true) {
	_draw_sprite_data(sprite, data, flush)
}
