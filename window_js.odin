#+feature dynamic-literals
#+private
package nais

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:strings"
import "core:sys/wasm/js"
import "core:time"

import "vendor:wgpu"

foreign import nais_js "nais"

Impl :: struct {
	initialized: bool,
	quit:        bool,
	input_buf:   [dynamic]byte,
}

_run :: proc(title: string, size: [2]int, flags: Flags, handler: Event_Handler) {
	size := size

	if .Windowed_Fullscreen in flags {
		rect := js.get_bounding_client_rect("body")
		size.x = int(rect.width)
		size.y = int(rect.height)
	}

	dpi := dpi()
	g_window.gfx.config.width  = u32(f32(size.x) * dpi.x)
	g_window.gfx.config.height = u32(f32(size.y) * dpi.y)

	js.set_element_style("wgpu-canvas", "width",  fmt.tprintf("%vpx", size.x))
	js.set_element_style("wgpu-canvas", "height", fmt.tprintf("%vpx", size.y))

	set_document_title(title)

	ok := js.add_event_listener("wgpu-canvas", .Pointer_Down, nil, __mouse_down_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Pointer_Up, nil, __mouse_up_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Pointer_Move, nil, __mouse_move_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Touch_Move, nil, __mouse_move_callback)
	assert(ok)
	ok = js.add_event_listener("wgpu-canvas", .Wheel, nil, __scroll_callback)
	assert(ok)

	ok  = js.add_window_event_listener(.Resize, nil, __size_callback)
	assert(ok)
	ok = js.add_window_event_listener(.Key_Down, nil, __key_down_callback)
	assert(ok)
	ok = js.add_window_event_listener(.Key_Press, nil, __key_press_callback)
	assert(ok)
	ok = js.add_window_event_listener(.Key_Up, nil, __key_up_callback)
	assert(ok)

	_gfx_init()
}

__initialized_callback :: proc() {
	g_window.impl.initialized = true
	g_window.handler(Initialized{})
}

@(private="file", export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context = g_window.ctx

	if !g_window.impl.initialized {
		return true
	}

	if g_window.impl.quit {
		return false
	}

	_gfx_frame()
	g_window.handler(Frame{ dt = clamp(dt, 0, 1) })
	_gfx_frame_end()

	return !g_window.impl.quit
}

// @(private="file", export)
// nais_input_buffer_resize :: proc "contextless" (size: i32) -> ([^]byte) {
// 	context = g_window.ctx
// 	err := resize(&g_window.impl.input_buf, size)
// 	assert(err == nil)
// 	return raw_data(g_window.impl.input_buf)
// }
//
// @(private="file", export)
// nais_input_buffer_ingest :: proc "contextless" () {
// 	context = g_window.ctx
// 	text := string(g_window.impl.input_buf[:])
// 	for ch in text {
// 		g_window.handler(Text{ch=ch})
// 	}
// }

@(fini)
__fini :: proc() {
	context = g_window.ctx
	g_window.handler(Quit{})
}

_quit :: proc() {
	g_window.impl.quit = true
}

_wait_for_events :: proc() {
	unimplemented()
}

_dpi :: proc() -> [2]f32 {
	dpi := js.device_pixel_ratio()
	return {f32(dpi), f32(dpi)}
}

_frame_buffer_size :: proc() -> [2]f32 {
	return {
		f32(g_window.gfx.config.width),
		f32(g_window.gfx.config.height)
	}
}

_window_size :: proc() -> [2]f32 {
	return {
		f32(g_window.gfx.config.width ),
		f32(g_window.gfx.config.height),
	} / dpi()
}

@(private="file")
__size_callback :: proc(e: js.Event) {
	context = g_window.ctx

	rect: js.Rect
	if .Windowed_Fullscreen in g_window.flags {
		rect = js.get_bounding_client_rect("body")
		js.set_element_style("wgpu-canvas", "width",  fmt.tprintf("%vpx", rect.width))
		js.set_element_style("wgpu-canvas", "height", fmt.tprintf("%vpx", rect.height))
	} else {
		rect = js.get_bounding_client_rect("wgpu-canvas")
	}

	if u32(rect.width) == g_window.gfx.config.width && u32(rect.height) == g_window.gfx.config.height {
		return
	}

	dpi := dpi()
	g_window.gfx.config.width  = u32(f32(rect.width)  * dpi.x)
	g_window.gfx.config.height = u32(f32(rect.height) * dpi.y)
	wgpu.SurfaceConfigure(g_window.gfx.surface, &g_window.gfx.config)

	for r in g_window.gfx.renderers {
		r(Renderer_Resize{})
	}
	g_window.handler(Resize{})
}

@(private="file")
KEY_MAP := map[string]Key {
	/* Named printable keys */
	"Space"           = .Space,
	"Quote"           = .Apostrophe,
	"Comma"           = .Comma,
	"Minus"           = .Minus,
	"Period"          = .Period,
	"Slash"           = .Slash,
	"Semicolon"       = .Semicolon,
	"Equal"           = .Equal,
	"BracketLeft"     = .Left_Bracket,
	"Backslash"       = .Backslash,
	"BracketRight"    = .Right_Bracket,
	"Backquote"       = .Grave_Accent,

	/* Alphanumeric characters */
	"Digit0"          = .N0,
	"Digit1"          = .N1,
	"Digit2"          = .N2,
	"Digit3"          = .N3,
	"Digit4"          = .N4,
	"Digit5"          = .N5,
	"Digit6"          = .N6,
	"Digit7"          = .N7,
	"Digit8"          = .N8,
	"Digit9"          = .N9,

	"KeyA"            = .A,
	"KeyB"            = .B,
	"KeyC"            = .C,
	"KeyD"            = .D,
	"KeyE"            = .E,
	"KeyF"            = .F,
	"KeyG"            = .G,
	"KeyH"            = .H,
	"KeyI"            = .I,
	"KeyJ"            = .J,
	"KeyK"            = .K,
	"KeyL"            = .L,
	"KeyM"            = .M,
	"KeyN"            = .N,
	"KeyO"            = .O,
	"KeyP"            = .P,
	"KeyQ"            = .Q,
	"KeyR"            = .R,
	"KeyS"            = .S,
	"KeyT"            = .T,
	"KeyU"            = .U,
	"KeyV"            = .V,
	"KeyW"            = .W,
	"KeyX"            = .X,
	"KeyY"            = .Y,
	"KeyZ"            = .Z,

	/** Function keys **/

	/* Named non-printable keys */
	"Escape"          = .Escape,
	"Enter"           = .Enter,
	"Tab"             = .Tab,
	"Backspace"       = .Backspace,
	"Insert"          = .Insert,
	"Delete"          = .Delete,
	"ArrowRight"      = .Right,
	"ArrowLeft"       = .Left,
	"ArrowDown"       = .Down,
	"ArrowUp"         = .Up,
	"PageUp"          = .Page_Up,
	"PageDown"        = .Page_Down,
	"Home"            = .Home,
	"End"             = .End,
	"CapsLock"        = .Caps_Lock,
	"ScrollLock"      = .Scroll_Lock,
	"NumLock"         = .Num_Lock,
	"PrintScreen"     = .Print_Screen,
	"Pause"           = .Pause,

	/* Function keys */
	"F1"              = .F1,
	"F2"              = .F2,
	"F3"              = .F3,
	"F4"              = .F4,
	"F5"              = .F5,
	"F6"              = .F6,
	"F7"              = .F7,
	"F8"              = .F8,
	"F9"              = .F9,
	"F10"             = .F10,
	"F11"             = .F11,
	"F12"             = .F12,
	"F13"             = .F13,
	"F14"             = .F14,
	"F15"             = .F15,
	"F16"             = .F16,
	"F17"             = .F17,
	"F18"             = .F18,
	"F19"             = .F19,
	"F20"             = .F20,
	"F21"             = .F21,
	"F22"             = .F22,
	"F23"             = .F23,
	"F24"             = .F24,
	"F25"             = .F25,

	/* Keypad numbers */
	"Numpad0"         = .KP_0,
	"Numpad1"         = .KP_1,
	"Numpad2"         = .KP_2,
	"Numpad3"         = .KP_3,
	"Numpad4"         = .KP_4,
	"Numpad5"         = .KP_5,
	"Numpad6"         = .KP_6,
	"Numpad7"         = .KP_7,
	"Numpad8"         = .KP_8,
	"Numpad9"         = .KP_9,

	/* Keypad named function keys */
	"NumpadDecimal"   = .KP_Decimal,
	"NumpadDivide"    = .KP_Divide,
	"NumpadMultiply"  = .KP_Multiply,
	"NumpadSubtract"  = .KP_Subtract,
	"NumpadAdd"       = .KP_Add,

	/* Modifier keys */
	"ShiftLeft"       = .Left_Shift,
	"ControlLeft"     = .Left_Control,
	"AltLeft"         = .Left_Alt,
	"MetaLeft"        = .Left_Super,
	"ShiftRight"      = .Right_Shift,
	"ControlRight"    = .Right_Control,
	"AltRight"        = .Right_Alt,
	"MetaRight"       = .Right_Super,
	"ContextMenu"     = .Menu,
}

/* Named printable keys */
_KEY_SPACE         :: 0
_KEY_APOSTROPHE    :: 1
_KEY_COMMA         :: 2
_KEY_MINUS         :: 3
_KEY_PERIOD        :: 4
_KEY_SLASH         :: 5
_KEY_SEMICOLON     :: 6
_KEY_EQUAL         :: 7
_KEY_LEFT_BRACKET  :: 8
_KEY_BACKSLASH     :: 9
_KEY_RIGHT_BRACKET :: 10
_KEY_GRAVE_ACCENT  :: 11
_KEY_WORLD_1       :: 12 // TODO: What is this?
_KEY_WORLD_2       :: 13 // TODO: What is this?

/* Alphanumeric characters */
_KEY_0 :: 14
_KEY_1 :: 15
_KEY_2 :: 16
_KEY_3 :: 17
_KEY_4 :: 18
_KEY_5 :: 19
_KEY_6 :: 20
_KEY_7 :: 21
_KEY_8 :: 22
_KEY_9 :: 23

_KEY_A :: 24
_KEY_B :: 25
_KEY_C :: 26
_KEY_D :: 27
_KEY_E :: 28
_KEY_F :: 29
_KEY_G :: 30
_KEY_H :: 31
_KEY_I :: 32
_KEY_J :: 33
_KEY_K :: 34
_KEY_L :: 35
_KEY_M :: 36
_KEY_N :: 37
_KEY_O :: 38
_KEY_P :: 39
_KEY_Q :: 40
_KEY_R :: 41
_KEY_S :: 42
_KEY_T :: 43
_KEY_U :: 44
_KEY_V :: 45
_KEY_W :: 46
_KEY_X :: 47
_KEY_Y :: 48
_KEY_Z :: 49


/** Function keys **/

/* Named non-printable keys */
_KEY_ESCAPE       :: 50
_KEY_ENTER        :: 51
_KEY_TAB          :: 52
_KEY_BACKSPACE    :: 53
_KEY_INSERT       :: 54
_KEY_DELETE       :: 55
_KEY_RIGHT        :: 56
_KEY_LEFT         :: 57
_KEY_DOWN         :: 58
_KEY_UP           :: 59
_KEY_PAGE_UP      :: 60
_KEY_PAGE_DOWN    :: 61
_KEY_HOME         :: 62
_KEY_END          :: 63
_KEY_CAPS_LOCK    :: 64
_KEY_SCROLL_LOCK  :: 65
_KEY_NUM_LOCK     :: 66
_KEY_PRINT_SCREEN :: 67
_KEY_PAUSE        :: 68

/* Function keys */
_KEY_F1  :: 69
_KEY_F2  :: 70
_KEY_F3  :: 71
_KEY_F4  :: 72
_KEY_F5  :: 73
_KEY_F6  :: 74
_KEY_F7  :: 75
_KEY_F8  :: 76
_KEY_F9  :: 77
_KEY_F10 :: 78
_KEY_F11 :: 79
_KEY_F12 :: 80
_KEY_F13 :: 81
_KEY_F14 :: 82
_KEY_F15 :: 83
_KEY_F16 :: 84
_KEY_F17 :: 85
_KEY_F18 :: 86
_KEY_F19 :: 87
_KEY_F20 :: 88
_KEY_F21 :: 89
_KEY_F22 :: 90
_KEY_F23 :: 91
_KEY_F24 :: 92
_KEY_F25 :: 93

/* Keypad numbers */
_KEY_KP_0 :: 94
_KEY_KP_1 :: 95
_KEY_KP_2 :: 96
_KEY_KP_3 :: 97
_KEY_KP_4 :: 98
_KEY_KP_5 :: 99
_KEY_KP_6 :: 100
_KEY_KP_7 :: 101
_KEY_KP_8 :: 102
_KEY_KP_9 :: 103

/* Keypad named function keys */
_KEY_KP_DECIMAL  :: 104
_KEY_KP_DIVIDE   :: 105
_KEY_KP_MULTIPLY :: 106
_KEY_KP_SUBTRACT :: 107
_KEY_KP_ADD      :: 108
_KEY_KP_ENTER    :: 109 // TODO: Looks like it doesn't exist?
_KEY_KP_EQUAL    :: 110 // TODO: Looks like it doesn't exist?

/* Modifier keys */
_KEY_LEFT_SHIFT    :: 111
_KEY_LEFT_CONTROL  :: 112
_KEY_LEFT_ALT      :: 113
_KEY_LEFT_SUPER    :: 114
_KEY_RIGHT_SHIFT   :: 115
_KEY_RIGHT_CONTROL :: 116
_KEY_RIGHT_ALT     :: 117
_KEY_RIGHT_SUPER   :: 118
_KEY_MENU          :: 119

_KEY_MOUSE_LEFT   :: 120
_KEY_MOUSE_RIGHT  :: 121
_KEY_MOUSE_MIDDLE :: 122
_KEY_MOUSE_4      :: 123
_KEY_MOUSE_5      :: 124
_KEY_MOUSE_6      :: 125
_KEY_MOUSE_7      :: 126
_KEY_MOUSE_8      :: 127

@(private="file")
__key_down_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("key down", e.key)

	key, ok := KEY_MAP[e.key.code]
	if !ok {
		log.warnf("key %v not recognized", e.key.code)
		return
	}

	g_window.handler(Input{key=key, action=.Pressed})
}

@(private="file")
__key_up_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("key up", e.key)

	key, ok := KEY_MAP[e.key.code]
	if !ok {
		log.warnf("key %v not recognized", e.key.code)
		return
	}

	g_window.handler(Input{key=key, action=.Released})
}

@(private="file")
__key_press_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("key press", e.key)

	i := e.data.key
	if i.ctrl || i.meta { return }
	if i.char >= 0x00 && i.char <= 0x1F { return }

	g_window.handler(Text{ch=rune(i.char)})
}

@(private="file")
__mouse_down_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("mouse down", e.mouse)

	js.event_prevent_default()

	if e.mouse.button > 7 {
		log.warnf("mouse down callback with mouse button %v out of supported mouse button range", e.mouse.button)
		return
	}

	g_window.handler(Move{
		position = linalg.array_cast(e.mouse.offset, f64),
	})

	g_window.handler(Input{
		key    = Key(_KEY_MOUSE_LEFT + e.mouse.button),
		action = .Pressed,
	})
}

@(private="file")
__mouse_up_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("mouse up", e.mouse)

	js.event_prevent_default()

	if e.mouse.button > 7 {
		log.warnf("mouse up callback with mouse button %v out of supported mouse button range", e.mouse.button)
		return
	}

	g_window.handler(Input{
		key    = Key(_KEY_MOUSE_LEFT + e.mouse.button),
		action = .Released,
	})
}

@(private="file")
__mouse_move_callback :: proc(e: js.Event) {
	context = g_window.ctx

	js.event_prevent_default()

	g_window.handler(Move{
		position = linalg.array_cast(e.mouse.offset, f64),
	})
}

@(private="file")
__scroll_callback :: proc(e: js.Event) {
	context = g_window.ctx

	log.info("scroll", e.scroll)

	g_window.handler(Scroll{
		delta = -e.scroll.delta,
	})
}

@(default_calling_convention="contextless")
foreign nais_js {
	set_document_title :: proc(title: string) ---
}

