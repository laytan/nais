package main

import           "core:encoding/cbor"
import           "core:log"
import           "core:math"
import           "core:math/linalg"
import           "core:strconv"
import           "core:strings"
import           "core:text/edit"
import ba        "core:container/bit_array"

import nais      "../.."
import clay      "../../../pkg/clay"
import nais_clay "../../integrations/clay"

CBOR :: `{
	"base64": 34("MTYgaXMgYSBuaWNlIG51bWJlcg=="),
	"biggest": 2(h'0f951a9fd3c158afdff08ab8e0'),
	"biggie": 18446744073709551615,
	"child": {
		"dyn": [
			"one",
			"two",
			"three",
			"four"
		],
		"mappy": {
			"one": 1,
			"two": 2,
			"four": 4,
			"three": 3
		},
		"my_integers": [
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8,
			9,
			10
		]
	},
	"comp": [
		32.0000,
		33.0000
	],
	"cstr": "Hellnope",
	"ennie": 0,
	"ennieb": 512,
	"iamint": -256,
	"important": "!",
	"my_bytes": h'',
	"neg": -69,
	"no": null,
	"nos": undefined,
	"now": 1(1701117968),
	"nowie": {
		"_nsec": 1701117968000000000
	},
	"onetwenty": 12345,
	"pos": 1212,
	"quat": [
		17.0000,
		18.0000,
		19.0000,
		16.0000
	],
	"renamed :)": 123123.12500000,
	"small_onetwenty": -18446744073709551615,
	"smallest": 3(h'0f951a9fd3c158afdff08ab8e0'),
	"smallie": -18446744073709551616,
	"str": "Hellope",
	"value": {
		16: "16 is a nice number",
		32: 69
	},
	"yes": true
}`

g: struct {
	editor:    edit.State,
	builder:   strings.Builder,
	file_path: [dynamic]byte,
	inp:       Input,
}

Font :: enum {
	Default,
	UI,
}

@(rodata)
font_data := [Font][]byte{
	.Default = #load("../_resources/SourceCodePro-500-100.ttf"),
	.UI      = #load("../_resources/NotoSans-500-100.ttf"),
}

fonts := [Font]nais.Font{}

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	nais.run("CBOR", {800, 450}, {.VSync, .Low_Power}, proc(ev: nais.Event) {
		#partial switch e in ev {
		case nais.Initialized:
			fonts[.Default] = nais.load_font_from_memory("Default", font_data[.Default])
			fonts[.UI]      = nais.load_font_from_memory("UI",      font_data[.UI])

			nais.background_set({30./255., 30./255., 46./255., 1})

			ok := ba.init(&g.inp.keys,     int(max(nais.Key)))
			ok &= ba.init(&g.inp.new_keys, int(max(nais.Key)))
			assert(ok)

			edit.init(&g.editor, context.allocator, context.allocator)
			g.editor.set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) { return nais.clipboard_set(text) }
			g.editor.get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) { return nais.clipboard()         }
			strings.builder_init(&g.builder)
			strings.write_string(&g.builder, CBOR)
			edit.setup_once(&g.editor, &g.builder)
			edit.move_to(&g.editor, .Start)

			append(&g.file_path, "scratch.odin")

			min_memory_size := clay.MinMemorySize()
			arena := clay.CreateArenaWithCapacityAndMemory(min_memory_size, make([^]byte, min_memory_size))
			clay.Initialize(arena)
			clay.SetMeasureTextFunction(nais_clay.measure_text)

		case nais.Resize:
			// no-op

		case nais.Input:
			i_press_release(e.key, e.action)

		case nais.Text:
			edit.input_rune(&g.editor, e.ch)

		case nais.Move:
			g.inp.cursor = linalg.array_cast(e.position, i32)
			clay.SetPointerPosition(linalg.array_cast(g.inp.cursor, f32) * nais.dpi())

		case nais.Scroll:
			g.inp.scroll = e.delta

		case nais.Frame:
			defer ba.clear(&g.inp.new_keys)

			fb  := nais.frame_buffer_size()
			dpi := nais.dpi()

			g.editor.current_time._nsec += i64(e.dt*1e9)

			clay.UpdateScrollContainers(false, linalg.array_cast(g.inp.scroll, f32), e.dt)
			g.inp.scroll = 0

			text := strings.to_string(g.builder)

			lh := nais.line_height(size=16)

			RED :: [4]f32{0, 0, 255, 255}

			clay.BeginLayout(i32(fb.x), i32(fb.y))
			if clay.Rectangle(clay.ID("screen"), clay.Layout({ sizing = { width = clay.SizingFixed(fb.x), height = clay.SizingFixed(fb.y) } }), clay.RectangleConfig({})) {
				if clay.Rectangle(clay.ID("main"), clay.Layout({ padding = {16, 16}, layoutDirection = .TOP_TO_BOTTOM, sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } }), clay.RectangleConfig({})) {
					if clay.Rectangle(clay.ID("top"), clay.Layout({ sizing = { width = clay.SizingGrow({}) } }), clay.RectangleConfig({})) {
						clay.Text(clay.ID("title"), string(g.file_path[:]), clay.TextConfig(UI_TEXT))
						if clay.Rectangle(clay.ID("right"), clay.Layout({ sizing = { width = clay.SizingGrow({}) }, childAlignment = { x = .RIGHT }, childGap = 16 }), clay.RectangleConfig({})) {

							// when #defined(os_open) {
							// 	if Button("Open") do os_open()
							// }
							//
							// when #defined(os_save) {
							// 	if Button("Save") {
							// 		t: Tokenizer
							// 		t.source = string(g.builder.buf[:])
							// 		t.full   = t.source
							// 		t.line   = 1
							// 		val, ok := parse(&t, context.temp_allocator)
							// 		assert(ok)
							// 		data, err := cbor.encode(val, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
							// 		assert(err == nil)
							// 		os_save(data)
							// 	}
							// }
							//
							// when #defined(os_save_as) {
							// 	if Button("Save As") {
							// 		t: Tokenizer
							// 		t.source = string(g.builder.buf[:])
							// 		t.full   = t.source
							// 		t.line   = 1
							// 		val, ok := parse(&t, context.temp_allocator)
							// 		assert(ok)
							// 		data, err := cbor.encode(val, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
							// 		assert(err == nil)
							// 		os_save_as(data)
							// 	}
							// }
						} // right
					} // top

					if clay.Scroll(clay.ID("content"), clay.Layout({ sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) }, layoutDirection = .TOP_TO_BOTTOM }), clay.ScrollConfig({ vertical = true })) {
						caret, selection_end := edit.sorted_selection(&g.editor)

						line_i: u32
						buf_i:  int
						iter := text
						for line in strings.split_lines_after_iterator(&iter) {
							line_len := len(line)
							line := strings.trim_right_space(line)

							id := clay.ID("line", line_i)
							clay.Text(id, line, clay.TextConfig({ fontSize=16, textColor={166, 218, 149, 255}, fontId = u16(Font.Default) }))

							// Handle clicking.
							if clay.PointerOver(id) && key_down(.Mouse_Left) {

								// NOTE: assuming the content starts at x 0.

								tab_width := nais.measure_text("    ", size=16).width

								at_x: f32
								at_i: int
								line_iter := line
								// TODO:
								// tabs: for tabbed in strings.split_after_iterator(&line_iter, "\t") {
								// 	tabbed := tabbed
								// 	if len(tabbed) > 0 && tabbed[0] == '\t' {
								// 		tabbed = tabbed[1:]
								// 		at_x += tab_width
								// 		if at_x >= f32(g.inp.cursor.x) * dpi.x {
								// 			break
								// 		}
								// 		at_i += 1
								// 	}
								//
								// 	for iter := fs.TextIterInit(&g.fs_renderer.fs, at_x, 0, tabbed); true; {
								// 		quad: fs.Quad
								// 		fs.TextIterNext(&g.fs_renderer.fs, &iter, &quad) or_break
								// 		at_x = quad.x1
								// 		if at_x >= f32(g.inp.cursor.x) * dpi.x {
								// 			break tabs
								// 		}
								// 		at_i += 1
								// 	}
								// }

								g.editor.selection = buf_i + at_i - 1
							}

							// Draw caret.
							if buf_i <= caret && buf_i + line_len > caret {
								column := caret - buf_i
								width := nais.measure_text(line[:column], size=16).width

								if clay.Floating(clay.ID("caret-container"), clay.Layout({ sizing = { width = clay.SizingFixed(16), height = clay.SizingFixed(lh) } }), clay.FloatingConfig({ parentId = id, offset = { width, 0 } })) {
									if clay.Rectangle(clay.ID("caret"), clay.Layout({ sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } }), clay.RectangleConfig({ color = { 166, 218, 149, 177 } })) {}
								}
							}

							line_i += 1
							buf_i  += line_len
						}
					} // content

					// pos := -f32(state.inp.scroll.y)
					// r.fs_draw_text(fs, text, pos={0, pos}, size=16, color={166, 218, 149, 255}, align_v=.Top)
					//
					// caret, selection_end := edit.sorted_selection(&state.editor)
					//
					// line := strings.count(text[:caret], "\n")
					// y := f32(line) * lh - f32(state.inp.scroll.y)
					//
					// current_line_start := max(0, strings.last_index_byte(text[:caret], '\n'))
					// current_line := strings.trim(text[current_line_start:caret], "\n")
					// x := r.fs_width(fs, current_line)
					//
					// caret_pos := [2]f32{x, y}
					// append(&state.sprites, r.Sprite_Data{
					// 	location = {4*17, 2*17},
					// 	size     = {16, 16},
					// 	anchor   = {0, 0},
					// 	position = caret_pos,
					// 	scale    = {16/16, lh/16},
					// 	rotation = 0,
					// 	color    = 0xAAa6da95,
					// })
					//
					// if selection_end > caret {
					// 	selected := text[caret:selection_end]
					// 	start := caret_pos
					// 	for line in strings.split_lines_iterator(&selected) {
					// 		width := r.fs_width(&state.fs_renderer, line)
					//
					// 		append(&state.sprites, r.Sprite_Data{
					// 			location = {4*17, 2*17},
					// 			size     = {16, 16},
					// 			anchor   = {0, 0},
					// 			position = start,
					// 			scale    = {width/16, lh/16},
					// 			rotation = 0,
					// 			color    = 0x66a6da95,
					// 		})
					//
					// 		start.x  = 0
					// 		start.y += lh
					// 	}
					// }

					if clay.Rectangle(clay.ID("bottom"), clay.Layout({ sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) }, childAlignment = { x = .RIGHT, y = .BOTTOM } }), clay.RectangleConfig({})) {
						// FPS over last 30 frames.
						@static frame_times: [30]f32
						@static frame_times_idx: int

						frame_times[frame_times_idx % len(frame_times)] = e.dt
						frame_times_idx += 1

						frame_time: f32
						for time in frame_times {
							frame_time += time
						}

						buf: [24]byte
						fps := strconv.itoa(buf[:], int(math.round(len(frame_times)/frame_time)))
						clay.Text(clay.ID("fps"), fps, clay.TextConfig(UI_TEXT))
					} // bottom
				} // main

				SCROLLBAR_WIDTH        :: 16
				SCROLLBAR_THUMB_HEIGHT :: 64
				SCROLLBAR_COLOR        :: [4]f32{244, 138, 173, 100}
				SCROLLBAR_THUMB_COLOR  :: [4]f32{244, 138, 173, 255}
				if clay.Rectangle(clay.ID("scrollbar"), clay.Layout({ sizing = { width = clay.SizingFixed(SCROLLBAR_WIDTH), height = clay.SizingGrow({}) }, layoutDirection = .TOP_TO_BOTTOM }), clay.RectangleConfig({ color = SCROLLBAR_COLOR })) {
					scroll := clay.GetScrollContainerData(clay.ID("content"))
					max    := scroll.contentDimensions.height - scroll.scrollContainerDimensions.height
					curr   := abs(scroll.scrollPosition.y)
					perc   := curr / max
					thumb  := perc * fb.y - SCROLLBAR_THUMB_HEIGHT
					if clay.Rectangle(clay.ID("thumb-offset"), clay.Layout({ sizing = { height = clay.SizingFixed(thumb) } }), clay.RectangleConfig({})) {}
					if clay.Rectangle(clay.ID("thumb"), clay.Layout({ sizing = { height = clay.SizingFixed(SCROLLBAR_THUMB_HEIGHT), width = clay.SizingGrow({}) } }), clay.RectangleConfig({ color = SCROLLBAR_THUMB_COLOR })) {}
				} // scrollbar
			} // screen

			render_commands := clay.EndLayout(i32(fb.x), i32(fb.y))
			nais_clay.render(&render_commands)
		}
	})
}

UI_TEXT :: clay.TextElementConfig{
	fontId    = u16(Font.UI),
	fontSize  = FONT_SIZE,
	textColor = 255,
}

FONT_SIZE :: 18

Button :: proc($ID: string) -> (clicked: bool) {
	hovered := clay.PointerOver(clay.ID(ID))

	if hovered && key_pressed(.Mouse_Left) {
		clicked = true
	}

	color: [4]f32
	switch {
	case clicked: color = {239,  95, 143, 255}
	case hovered: color = {242, 121, 161, 255}
	case:         color = {244, 138, 173, 255}
	}

	if clay.Rectangle(clay.ID(ID), clay.Layout({ padding = {12, 6} }), clay.RectangleConfig({ color = color })) {
		clay.Text(clay.ID(ID + "-text"), clay.MakeString(ID), clay.TextConfig(UI_TEXT))
	}
	return
}

// TODO:
// on_file :: proc(path: string, data: []byte) {
// 	clear(&g.file_path)
// 	append(&g.file_path, path)
//
// 	value, err := cbor.decode(string(data), allocator=context.temp_allocator)
// 	fmt.assertf(err == nil, "decode error: %v", err)	
//
// 	diag := cbor.to_diagnostic_format(value, allocator=context.temp_allocator)
//
// 	state.editor.selection = 0
// 	strings.builder_reset(&state.builder)
// 	edit.input_text(&state.editor, diag)
// 	state.editor.selection = 0
// }

// TODO:
// - bind the rest of the command of core:text/edit
// - zooming
// - if action while caret not on screen, first focus view/scroll on caret
// - horizontal scrolling
// - only draw text that is on screen
// - fix bug removing all content
// - error handling in the parser and display those errors
// - always doing preventDefault is probably bad
// - Cmd+foo keybinds on MacOS
