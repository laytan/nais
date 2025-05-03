package nais

import fs "vendor:fontstash"

Font :: distinct int

Text_Align_Horizontal :: enum {
	Left   = int(fs.AlignHorizontal.LEFT),
	Center = int(fs.AlignHorizontal.CENTER),
	Right  = int(fs.AlignHorizontal.RIGHT),
}

Text_Align_Vertical :: enum {
	Top      = int(fs.AlignVertical.TOP),
	Middle   = int(fs.AlignVertical.MIDDLE),
	Bottom   = int(fs.AlignVertical.BOTTOM),
	Baseline = int(fs.AlignVertical.BASELINE),
}

load_font_from_file :: proc() {
	unimplemented()
}

load_font_from_memory :: proc(name: string, data: []byte) -> Font {
	return _load_font_from_memory(name, data)
}

// NOTE: Maybe?
// unload_font :: proc() {
// 	unimplemented()
// }

// TODO: way to set current font that's used when draw_text doesn't specify one?

// TODO: panic when no font is loaded

// TODO: fix this so it is positioned based on window size and not frame buffer size.

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
) {
	_draw_text(text, pos, size, color, blur, spacing, font, align_h, align_v)
}

// Text_Bounds :: struct {
// 	width: f32,
// 	min:   [2]f32,
// 	max:   [2]f32,
// }

measure_text :: proc(
    text: string,
    size: f32 = 36,
    spacing: f32 = 0,
    blur: f32 = 0,
    font: Font = 0,
) -> (w, h: f32) {
	return _measure_text(text, size, spacing, blur, font)
}

Measure_Text_Iter :: struct {
	iter:  fs.TextIter,
	scale: f32,
	i:     int,
}

measure_text_iter_init :: proc(
	iter: ^Measure_Text_Iter,
	text: string,
	size: f32 = 36,
	spacing: f32 = 0,
	blur: f32 = 0,
	font: Font = 0,
) {
	_measure_text_iter_init(iter, text, size, spacing, blur, font)
}

measure_text_iter :: proc(iter: ^Measure_Text_Iter) -> (w: f32, i: int, ok: bool) {
	return _measure_text_iter(iter)
}

line_height :: proc(font: Font = 0, size: f32 = 36) -> f32 {
	return _line_height(font, size)
}
