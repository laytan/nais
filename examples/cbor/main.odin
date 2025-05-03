package main

import           "base:runtime"
import           "core:encoding/cbor"
import           "core:log"
import           "core:math"
import           "core:math/linalg"
import           "core:strconv"
import           "core:strings"
import           "core:text/edit"
import ba        "core:container/bit_array"

import clay      "pkg:clay"

import nais      "../.."
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
	editor:    edit.State `cbor:"-"`,
	builder:   strings.Builder,
	file_path: [dynamic]byte,
	inp:       Input `cbor:"-"`,
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

ctx: runtime.Context

init_state :: proc() {
	strings.builder_init(&g.builder)
	strings.write_string(&g.builder, CBOR)

	resize(&g.file_path, 0)
	append(&g.file_path, "scratch.odin")
}

reload_state :: proc() {
	if state, ok := nais.persist_get("state"); ok {
		if err := cbor.unmarshal(state, &g); err == nil {
			return
		}
	}

	init_state()
}

main :: proc() {
	context.logger = log.create_console_logger(.Info)
	ctx = context

	nais.run("CBOR", {800, 450}, {.VSync, .Low_Power, .Windowed_Fullscreen, .Save_Window_State}, proc(ev: nais.Event) {
		#partial switch e in ev {
		case nais.Initialized:
			fonts[.Default] = nais.load_font_from_memory("Default", font_data[.Default])
			fonts[.UI]      = nais.load_font_from_memory("UI",      font_data[.UI])

			nais.background_set({30./255., 30./255., 46./255., 1})

			ok := ba.init(&g.inp.keys,     int(max(nais.Key)))
			ok &= ba.init(&g.inp.new_keys, int(max(nais.Key)))
			assert(ok)

			reload_state()

			edit.init(&g.editor, context.allocator, context.allocator)
			g.editor.set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) { return nais.clipboard_set(text) }
			g.editor.get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) { return nais.clipboard()         }
			edit.setup_once(&g.editor, &g.builder)
			edit.move_to(&g.editor, .Start)

			min_memory_size := clay.MinMemorySize()
			arena := clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), make([^]byte, min_memory_size))

			sz := nais.window_size()
			clay.Initialize(arena, {sz.x, sz.y}, { handler = handle_clay_error })

			clay.SetMeasureTextFunction(nais_clay.measure_text, nil)

		case nais.Quit:
			state, err := cbor.marshal(g)
			if err != nil {
				log.errorf("marshal state: %v", err)
				return
			}

			if !nais.persist_set("state", state) {
				log.errorf("persist state: %v", state)
			}

		case nais.Resize:
			sz := nais.window_size()
			clay.SetLayoutDimensions({sz.x, sz.y})

		case nais.Input:
			i_press_release(e.key, e.action)

		case nais.Text:
			edit.input_rune(&g.editor, e.ch)

		case nais.Move:
			g.inp.cursor = linalg.array_cast(e.position, i32)

		case nais.Scroll:
			g.inp.scroll = e.delta

		case nais.Frame:
			defer ba.clear(&g.inp.new_keys)

			sz := nais.window_size()

			g.editor.current_time._nsec += i64(e.dt*1e9)

			clay.SetPointerState(linalg.array_cast(g.inp.cursor, f32), key_down(.Mouse_Left))

			clay.UpdateScrollContainers(false, linalg.array_cast(g.inp.scroll, f32), e.dt)
			g.inp.scroll = 0

			text := strings.to_string(g.builder)

			lh := nais.line_height(size=16)

			RED :: [4]f32{0, 0, 255, 255}

			clay.BeginLayout()

			if clay.UI()({
				id = clay.ID("screen"),
				layout = { sizing = { width = clay.SizingFixed(sz.x), height = clay.SizingFixed(sz.y) } },
			}) {
				if clay.UI()({
					id = clay.ID("main"),
					layout = { padding = { 16, 16, 16, 16 }, layoutDirection = .TopToBottom, sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } },
				}) {
					if clay.UI()({
						id = clay.ID("top"),
						layout = {  sizing = { width = clay.SizingGrow({}) } },
					}) {
						clay.TextDynamic(string(g.file_path[:]), clay.TextConfig(UI_TEXT))

						if clay.UI()({
							id = clay.ID("right"),
							layout = { sizing = { width = clay.SizingGrow({}) }, childAlignment = { x = .Right }, childGap = 16 },
						}) {
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

					if clay.UI()({
						id = clay.ID("content"),
						layout = { sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) }, layoutDirection = .TopToBottom },
						scroll = { vertical = true },
					}) {
						caret, selection_end := edit.sorted_selection(&g.editor)

						line_i: u32
						buf_i:  int
						iter := text
						for line in strings.split_lines_after_iterator(&iter) {
							line_len := len(line)

							SELECTION_COLOR :: [4]f32{ 166, 218, 149, 177 }

							line_is_selected           := false

							line_is_partially_selected := false
							partial_width: f32
							partial_off:   f32

							caret_before    := caret < buf_i + line_len
							selection_after := buf_i <= selection_end
							if caret_before && selection_after {
								start  := 0
								caret_on_line := buf_i <= caret && buf_i + line_len > caret
								if caret_on_line {
									start = caret - buf_i
									partial_off, _ = nais.measure_text(line[:start], size=16)
								}

								end := line_len
								end_on_line := buf_i <= selection_end && buf_i + line_len > selection_end
								if end_on_line {
									end = selection_end - buf_i
								}

								if !caret_on_line && !end_on_line {
									line_is_selected = true
								} else {
									line_is_partially_selected = true
									partial_width, _ = nais.measure_text(line[start:end], size=16)
								}
							}

							line_id := clay.ID("line", line_i)
							if clay.UI()({ id = line_id, layout = { padding = { right = 8 } }, backgroundColor = line_is_selected ? SELECTION_COLOR : {} }) {
								clay.TextDynamic(line, clay.TextConfig({ fontSize=16, textColor={166, 218, 149, 255}, fontId = u16(Font.Default) }))

								if clay.PointerOver(line_id) && key_down(.Mouse_Left) {
									data := clay.GetElementData(line_id)
									assert(data.found)

									target := f32(g.inp.cursor.x) - data.boundingBox.x
									target_char: int

									iter: nais.Measure_Text_Iter
									nais.measure_text_iter_init(&iter, line, size=16)
									for w, i in nais.measure_text_iter(&iter) {
										target_char = i
										if w > target {
											break
										}
									}

									if key_pressed(.Mouse_Left) {
										g.editor.selection    = buf_i + target_char
									} else {
										g.editor.selection[1] = buf_i + target_char
									}
								}

								if line_is_partially_selected {
									if clay.UI()({
										id = clay.ID("selection", line_i),
										layout = { sizing = { width = clay.SizingFixed(max(2, partial_width)), height = clay.SizingFixed(lh) } },
										floating = { attachTo = .Parent, offset = { partial_off, 0 } },
										backgroundColor = SELECTION_COLOR,
									}) {
									}
								}

							}

							line_i += 1
							buf_i  += line_len
						}
					} // content

					if clay.UI()({
						id = clay.ID("bottom"),
						layout = { sizing = { width = clay.SizingGrow({}), height = clay.SizingFit({}) }, childAlignment = { x = .Right, y = .Bottom } },
					}) {
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
						clay.TextDynamic(fps, clay.TextConfig(UI_TEXT))
					} // bottom
				} // main

				SCROLLBAR_WIDTH        :: 16
				SCROLLBAR_THUMB_HEIGHT :: 64
				SCROLLBAR_COLOR        :: [4]f32{244, 138, 173, 100}
				SCROLLBAR_THUMB_COLOR  :: [4]f32{244, 138, 173, 255}
				if clay.UI()({
					id = clay.ID("scrollbar"),
					layout = { sizing = { width = clay.SizingFixed(SCROLLBAR_WIDTH), height = clay.SizingGrow({}) }, layoutDirection = .TopToBottom},
					backgroundColor = SCROLLBAR_COLOR,
				}) {
					scroll := clay.GetScrollContainerData(clay.GetElementId(clay.MakeString("content")))
					max    := scroll.contentDimensions.height - scroll.scrollContainerDimensions.height
					curr   := abs(scroll.scrollPosition.y)
					perc   := curr / max
					thumb  := perc * sz.y - SCROLLBAR_THUMB_HEIGHT
					if clay.UI()({
						id = clay.ID("thumb-offset"),
						layout = { sizing = { height = clay.SizingFixed(thumb) } },
					}) {}
					if clay.UI()({
						id = clay.ID("thumb"),
						layout = { sizing = { height = clay.SizingFixed(SCROLLBAR_THUMB_HEIGHT), width = clay.SizingGrow({}) } },
						backgroundColor = SCROLLBAR_THUMB_COLOR,
					}) {}
				} // scrollbar
			} // screen

			render_commands := clay.EndLayout()
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

	if clay.UI(clay.ID(ID), clay.Layout({ padding = {12, 6} }), clay.Rectangle({ color = color })) {
		clay.Text(clay.MakeString(ID), clay.TextConfig(UI_TEXT))
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

handle_clay_error :: proc "c" (err: clay.ErrorData) {
	context = ctx
	log.errorf("[clay][%v]: %v", err.errorType, string(err.errorText.chars[:err.errorText.length]))
}
