package nais

import "base:runtime"
import "core:encoding/cbor"
import "core:log"

import "vendor:wgpu"

// TODO: 3 layers of the API, `public`, `_internal`, and `__private`. Where users can't get to `__private`.

// TODO: draw_fps

@(private)
g_window := struct {
	running:   bool,
	ctx:       runtime.Context,
	handler:   Event_Handler,
	flags:     Flags,
	impl:      Impl,
	gfx:       struct {
		renderers:     [dynamic]Renderer,
		curr_renderer: Renderer,
		surface:       wgpu.Surface,
		config:        wgpu.SurfaceConfiguration,
		queue:         wgpu.Queue,
		background:    wgpu.Color,

		frame: struct {
			texture: wgpu.SurfaceTexture,
			view:    wgpu.TextureView,
			encoder: wgpu.CommandEncoder,
			pass:    wgpu.RenderPassEncoder,
			buffers: [dynamic]wgpu.CommandBuffer,
		},
	},
}{}

Event :: union {
	Initialized, // Just after run, has info about the window, gpu, etc.
	Frame,       // Request a frame to be drawn.
	Resize,      // Window resized.
	Input,       // An input action.
	Text,        // Text input action.
	Scroll,      // Scrolled.
	Move,        // Moved cursor.
	Serialize,
	Deserialize,
	// Drop,        // Dropped file(s).
	// Quit,        // Can we reliably call this in JS?
}

Input :: struct {
	key:    Key,
	action: Key_Action,
}

Move :: struct {
	position: [2]f64,
}

Scroll :: struct {
	delta: [2]f64,
}

Text :: struct {
	ch: rune,
}

Initialized :: struct {}

Frame :: struct {
	dt: f32,
}

Resize :: struct {}

Serialize :: struct {
	data: ^[]byte,
}

Deserialize :: struct {
	data: []byte,
}

Event_Handler :: #type proc(event: Event)

// TODO: joystick, gamepad input.

Key_Action :: enum {
	Released,
	Pressed,
	// Repeated,
}

Key :: enum {
	Mouse_Left    = _KEY_MOUSE_LEFT,
	Mouse_Right   = _KEY_MOUSE_RIGHT,
	Mouse_Middle  = _KEY_MOUSE_MIDDLE,
	Mouse_4       = _KEY_MOUSE_4,
	Mouse_5       = _KEY_MOUSE_5,
	Mouse_6       = _KEY_MOUSE_6,
	Mouse_7       = _KEY_MOUSE_7,
	Mouse_8       = _KEY_MOUSE_8,

	/* Named printable keys */
	Space         = _KEY_SPACE,          
	Apostrophe    = _KEY_APOSTROPHE,    /* ' */
	Comma         = _KEY_COMMA,         /* , */
	Minus         = _KEY_MINUS,         /* - */
	Period        = _KEY_PERIOD,        /* . */
	Slash         = _KEY_SLASH,         /* / */
	Semicolon     = _KEY_SEMICOLON,     /* ; */
	Equal         = _KEY_EQUAL,         /* :: */
	Left_Bracket  = _KEY_LEFT_BRACKET,  /* [ */
	Backslash     = _KEY_BACKSLASH,     /* \ */
	Right_Bracket = _KEY_RIGHT_BRACKET, /* ] */
	Grave_Accent  = _KEY_GRAVE_ACCENT,  /* ` */
	World_1       = _KEY_WORLD_1,       /* non-US #1 */
	World_2       = _KEY_WORLD_2,       /* non-US #2 */

	/* Alphanumeric characters */
	N0 = _KEY_0,
	N1 = _KEY_1,
	N2 = _KEY_2,
	N3 = _KEY_3,
	N4 = _KEY_4,
	N5 = _KEY_5,
	N6 = _KEY_6,
	N7 = _KEY_7,
	N8 = _KEY_8,
	N9 = _KEY_9,

	A = _KEY_A,
	B = _KEY_B,
	C = _KEY_C,
	D = _KEY_D,
	E = _KEY_E,
	F = _KEY_F,
	G = _KEY_G,
	H = _KEY_H,
	I = _KEY_I,
	J = _KEY_J,
	K = _KEY_K,
	L = _KEY_L,
	M = _KEY_M,
	N = _KEY_N,
	O = _KEY_O,
	P = _KEY_P,
	Q = _KEY_Q,
	R = _KEY_R,
	S = _KEY_S,
	T = _KEY_T,
	U = _KEY_U,
	V = _KEY_V,
	W = _KEY_W,
	X = _KEY_X,
	Y = _KEY_Y,
	Z = _KEY_Z,


	/** Function keys **/

	/* Named non-printable keys */
	Escape       = _KEY_ESCAPE,
	Enter        = _KEY_ENTER,
	Tab          = _KEY_TAB,
	Backspace    = _KEY_BACKSPACE,
	Insert       = _KEY_INSERT,
	Delete       = _KEY_DELETE,
	Right        = _KEY_RIGHT,
	Left         = _KEY_LEFT,
	Down         = _KEY_DOWN,
	Up           = _KEY_UP,
	Page_Up      = _KEY_PAGE_UP,
	Page_Down    = _KEY_PAGE_DOWN,
	Home         = _KEY_HOME,
	End          = _KEY_END,
	Caps_Lock    = _KEY_CAPS_LOCK,
	Scroll_Lock  = _KEY_SCROLL_LOCK,
	Num_Lock     = _KEY_NUM_LOCK,
	Print_Screen = _KEY_PRINT_SCREEN,
	Pause        = _KEY_PAUSE,

	/* Function keys */
	F1  = _KEY_F1,
	F2  = _KEY_F2,
	F3  = _KEY_F3,
	F4  = _KEY_F4,
	F5  = _KEY_F5,
	F6  = _KEY_F6,
	F7  = _KEY_F7,
	F8  = _KEY_F8,
	F9  = _KEY_F9,
	F10 = _KEY_F10,
	F11 = _KEY_F11,
	F12 = _KEY_F12,
	F13 = _KEY_F13,
	F14 = _KEY_F14,
	F15 = _KEY_F15,
	F16 = _KEY_F16,
	F17 = _KEY_F17,
	F18 = _KEY_F18,
	F19 = _KEY_F19,
	F20 = _KEY_F20,
	F21 = _KEY_F21,
	F22 = _KEY_F22,
	F23 = _KEY_F23,
	F24 = _KEY_F24,
	F25 = _KEY_F25,

	/* Keypad numbers */
	KP_0 = _KEY_KP_0,
	KP_1 = _KEY_KP_1,
	KP_2 = _KEY_KP_2,
	KP_3 = _KEY_KP_3,
	KP_4 = _KEY_KP_4,
	KP_5 = _KEY_KP_5,
	KP_6 = _KEY_KP_6,
	KP_7 = _KEY_KP_7,
	KP_8 = _KEY_KP_8,
	KP_9 = _KEY_KP_9,

	/* Keypad named function keys */
	KP_Decimal  = _KEY_KP_DECIMAL,
	KP_Divide   = _KEY_KP_DIVIDE,
	KP_Multiply = _KEY_KP_MULTIPLY,
	KP_Subtract = _KEY_KP_SUBTRACT,
	KP_Add      = _KEY_KP_ADD,
	KP_Enter    = _KEY_KP_ENTER,
	KP_Equal    = _KEY_KP_EQUAL,

	/* Modifier keys */
	Left_Shift    = _KEY_LEFT_SHIFT,
	Left_Control  = _KEY_LEFT_CONTROL,
	Left_Alt      = _KEY_LEFT_ALT,
	Left_Super    = _KEY_LEFT_SUPER,
	Right_Shift   = _KEY_RIGHT_SHIFT,
	Right_Control = _KEY_RIGHT_CONTROL,
	Right_Alt     = _KEY_RIGHT_ALT,
	Right_Super   = _KEY_RIGHT_SUPER,
	Menu          = _KEY_MENU,
}

Flag :: enum {
	VSync,
	Low_Power,
	// TODO: separate functions or do we want them as flags?
	// Clipboard,
	// Fullscreen,

	// NOTE: not sure about this being a flag, separate function maybe?
	// can also provide a `screen_size()` and let user do it themselves.
	Windowed_Fullscreen,

	Debug_Renderer, // Very verbose wgpu logs.
}
Flags :: bit_set[Flag]

run :: proc(title: string, size: [2]int, flags: Flags, handler: Event_Handler) {
	assert(!g_window.running, "already running")
	g_window.running   = true
	g_window.ctx       = context
	g_window.handler   = handler
	g_window.flags     = flags

	g_window.gfx.renderers.allocator = context.allocator

	// NOTE: do we need to allow changing format and alphaMode?
	g_window.gfx.config = {
		usage       = { .RenderAttachment },
		format      = .BGRA8Unorm,
		presentMode = .Fifo if .VSync in flags else .Immediate,
		alphaMode   = .Opaque,
	}

	_run(title, size, flags, handler)
}

default_context :: proc() -> runtime.Context {
	return g_window.ctx
}

handler :: proc(new: Event_Handler = nil) -> Event_Handler {
	if new != nil {
		old := g_window.handler

		deserialize := Deserialize{}
		old(Serialize{data = &deserialize.data})

		v, err := cbor.decode(string(deserialize.data))
		assert(err == nil)
		log.infof("%v %v", cbor.to_diagnostic_format(v))

		g_window.ctx = context
		g_window.handler = new
		new(deserialize)

		return old
	}

	return g_window.handler
}

@(private)
_initialized_callback :: proc() {
	__initialized_callback()
}

target_fps :: proc(fps: int) {
	unimplemented()
}

title :: proc(text: string) {
	unimplemented()
}

icon :: proc() {
	unimplemented()
}

// TODO: this should wait after having shown the frame, not right when it's called.
// // TODO: max wait param.
// wait_for_event :: proc() {
// 	_wait_for_events()
// }

// delta_time :: proc() -> f32 {
// }

dpi :: proc() -> [2]f32 {
	return _dpi()
}

frame_buffer_size :: proc() -> [2]f32 {
	return _frame_buffer_size()
}

window_size :: proc() -> [2]f32 {
	return _window_size()
}

window_size_set :: proc(size: [2]f32) {
	unimplemented()
}

clipboard :: proc() -> (string, bool) {
	unimplemented()
}

clipboard_set :: proc(text: string) -> bool {
	unimplemented()
}
