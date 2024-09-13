package nais_b

import "core:sys/posix"

import "vendor:glfw"

import fs "vendor:fontstash"
import ".."

RELEASE :: #config(NAIS_RELEASE, true)

Event :: nais.Event
Event_Handler :: nais.Event_Handler
Font :: nais.Font
Text_Align_Vertical :: nais.Text_Align_Vertical
Flags :: nais.Flags
Text_Align_Horizontal :: nais.Text_Align_Horizontal
Input :: nais.Input
Move :: nais.Move
Resize :: nais.Resize
Text :: nais.Text
Scroll :: nais.Scroll
Initialized :: nais.Initialized
Frame :: nais.Frame
Serialize :: nais.Serialize
Deserialize :: nais.Deserialize
Sprite :: nais.Sprite
File_Type :: nais.File_Type
Text_Bounds :: nais.Text_Bounds

when RELEASE {

run                     :: nais.run
handler                 :: nais.handler
load_font_from_memory   :: nais.load_font_from_memory
background_set          :: nais.background_set
frame_buffer_size       :: nais.frame_buffer_size
window_size             :: nais.window_size
draw_text               :: nais.draw_text
load_sprite_from_memory :: nais.load_sprite_from_memory
draw_sprite             :: nais.draw_sprite 
draw_rectangle          :: nais.draw_rectangle
measure_text            :: nais.measure_text

} else when ODIN_BUILD_MODE == .Dynamic {

run :: proc(title: string, size: [2]int, flags: Flags, _handler: Event_Handler) {
	// TODO: set title, size, and flags.

	handler(_handler)
}

@(init)
load_lib :: proc() {
	lib := posix.dlopen(nil, posix.RTLD_LOCAL)
	assert(lib != nil)

	load :: proc(lib: posix.Symbol_Table, ptr: ^$T, name: cstring) {
		addr := posix.dlsym(lib, name)
		if addr == nil {
			panic(string(posix.dlerror()))
		}
		(^rawptr)(ptr)^ = addr
	}
	load(lib, &handler, "nais_handler")
	load(lib, &load_font_from_memory, "nais_load_font_from_memory")
	load(lib, &background_set, "nais_background_set")
	load(lib, &frame_buffer_size, "nais_frame_buffer_size")
	load(lib, &window_size, "nais_window_size")
	load(lib, &draw_text, "nais_draw_text")
	load(lib, &load_sprite_from_memory, "nais_load_sprite_from_memory")
	load(lib, &draw_sprite, "nais_draw_sprite")
	load(lib, &draw_rectangle, "nais_draw_rectangle")
	load(lib, &measure_text, "nais_measure_text")
}

handler: proc(new: Event_Handler) -> Event_Handler
load_font_from_memory: proc(title: string, data: []byte) -> Font
background_set: proc(color: [4]f64)
frame_buffer_size: proc() -> [2]f32
window_size: proc() -> [2]f32
draw_text: proc(
	text: string,
	pos: [2]f32,
	size: f32 = 36,
	color: [4]u8 = max(u8),
	blur: f32 = 0,
	spacing: f32 = 0,
	font: Font = 0,
	align_h: Text_Align_Horizontal = .Left,
	align_v: Text_Align_Vertical   = .Baseline,
	x_inc: ^f32 = nil,
	y_inc: ^f32 = nil,
	flush := true,
)
load_sprite_from_memory: proc(data: []byte, type: File_Type) -> Sprite
draw_sprite: proc(sprite: Sprite, position: [2]f32, anchor: [2]f32 = 0, scale: [2]f32 = 1, rotation: f32 = 0, color: u32 = 0xFFFFFFFF, flush := true)
draw_rectangle: proc(position: [2]f32, size: [2]f32, color: u32, anchor: [2]f32 = 0, rotation: f32 = 0, flush := true)
measure_text: proc(
    text: string,
	pos: [2]f32 = 0,
    size: f32 = 36,
    spacing: f32 = 0,
    blur: f32 = 0,
    font: Font = 0,
    align_h: Text_Align_Horizontal = .Left,
    align_v: Text_Align_Vertical   = .Baseline,
) -> Text_Bounds

} else {

@(require, export, link_name="nais_run")
run :: proc(title: string, size: [2]int, flags: Flags, handler: Event_Handler) {
	nais.run(title, size, flags, handler)
}

@(require, export, link_name="nais_handler")
handler :: proc(new: Event_Handler = nil) -> Event_Handler {
	return nais.handler(new)
}

@(require, export, link_name="nais_load_font_from_memory")
load_font_from_memory :: proc(name: string, data: []byte) -> Font {
	return nais.load_font_from_memory(name, data)
}

@(require, export, link_name="nais_background_set")
background_set :: proc(color: [4]f64) {
	nais.background_set(color)
}

@(require, export, link_name="nais_frame_buffer_size")
frame_buffer_size :: proc() -> [2]f32 {
	return nais.frame_buffer_size()
}

@(require, export, link_name="nais_window_size")
window_size :: proc() -> [2]f32 {
	return nais.window_size()
}

@(require, export, link_name="nais_load_sprite_from_memory")
load_sprite_from_memory :: proc(data: []byte, type: File_Type) -> Sprite {
	return nais.load_sprite_from_memory(data, type)
}

@(require, export, link_name="nais_draw_text")
draw_text :: proc(
    text: string,
    pos: [2]f32,
    size: f32 = 36,
    color: [4]u8 = max(u8),
    blur: f32 = 0,
    spacing: f32 = 0,
    font: Font = 0,
    align_h: Text_Align_Horizontal = .Left,
    align_v: Text_Align_Vertical   = .Baseline,
    x_inc: ^f32 = nil,
    y_inc: ^f32 = nil,
	flush := true,
) {
	nais.draw_text(text, pos, size, color, blur, spacing, font, align_h, align_v, x_inc, y_inc, flush)
}

@(require, export, link_name="nais_draw_sprite")
draw_sprite :: proc(sprite: Sprite, position: [2]f32, anchor: [2]f32 = 0, scale: [2]f32 = 1, rotation: f32 = 0, color: u32 = 0xFFFFFFFF, flush := true) {
	nais.draw_sprite(sprite, position, anchor, scale, rotation, color, flush)
}

@(require, export, link_name="nais_draw_rectangle")
draw_rectangle :: proc(position: [2]f32, size: [2]f32, color: u32, anchor: [2]f32 = 0, rotation: f32 = 0, flush := true) {
	nais.draw_rectangle(position, size, color, anchor, rotation, flush)
}

@(require, export, link_name="nais_measure_text")
measure_text :: proc(
    text: string,
	pos: [2]f32 = 0,
    size: f32 = 36,
    spacing: f32 = 0,
    blur: f32 = 0,
    font: Font = 0,
    align_h: Text_Align_Horizontal = .Left,
    align_v: Text_Align_Vertical   = .Baseline,
) -> Text_Bounds {
	return nais.measure_text(text, pos, size, spacing, blur, font, align_h, align_v)
}
}
