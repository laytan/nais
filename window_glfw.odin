#+build !js
#+private
package nais

import "core:encoding/cbor"
import "core:log"
import "core:math/linalg"
import "core:strings"
import "core:sys/posix"
import "core:time"

import "vendor:glfw"
import "vendor:wgpu"

Impl :: struct {
	handle: glfw.WindowHandle,
}

Hot :: struct {
	size: [2]int,
	pos:  [2]int,
}

_run :: proc(title: string, size: [2]int, flags: Flags, handler: Event_Handler) {
	size := size

	glfw.SetErrorCallback(__error_callback)

	glfw.Init()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	if .Windowed_Fullscreen in flags {
		monitor := glfw.GetPrimaryMonitor()
		mode    := glfw.GetVideoMode(monitor)
		size.x = int(mode.width)
		size.y = int(mode.height)
	}

	hot: Hot
	if .Save_Window_State in flags {
		if data, has_data := persist_get(".window-state"); has_data {
			uerr := cbor.unmarshal(string(data), &hot)
			assert(uerr == nil)
			if hot.size.x > 0 && hot.size.y > 0 {
				size = hot.size
			}
		}
	}

	g_window.impl.handle = glfw.CreateWindow(i32(size.x), i32(size.y), strings.clone_to_cstring(title, context.temp_allocator), nil, nil)
	assert(g_window.impl.handle != nil)

	if .Save_Window_State in flags {
		glfw.SetWindowPos(g_window.impl.handle, i32(hot.pos.x), i32(hot.pos.y))
	}

	glfw.SetKeyCallback(        g_window.impl.handle, __key_callback         )
	glfw.SetMouseButtonCallback(g_window.impl.handle, __mouse_button_callback)
	glfw.SetCursorPosCallback(  g_window.impl.handle, __cursor_pos_callback  )
	glfw.SetScrollCallback(     g_window.impl.handle, __scroll_callback      )
	glfw.SetCharCallback(       g_window.impl.handle, __char_callback        )

	glfw.SetFramebufferSizeCallback(g_window.impl.handle, __size_callback)
	// // glfw.SetDropCallback(state.os.window, drop_callback)

	fb := frame_buffer_size()
	g_window.gfx.config.width  = u32(fb.x)
	g_window.gfx.config.height = u32(fb.y)

	_gfx_init()
}

__initialized_callback :: proc() {
	handle :: proc "c" (sig: posix.Signal) {
		context = g_window.ctx
		log.warnf("[nais]: caught signal %s, quitting", posix.strsignal(sig))
		_quit()

		posix.signal(.SIGTERM, auto_cast posix.SIG_DFL)
		posix.signal(.SIGINT,  auto_cast posix.SIG_DFL)
		posix.signal(.SIGQUIT, auto_cast posix.SIG_DFL)
	}
	posix.signal(.SIGTERM, handle)
	posix.signal(.SIGINT,  handle)
	posix.signal(.SIGQUIT, handle)

	g_window.handler(Initialized{})

	for !glfw.WindowShouldClose(g_window.impl.handle) {
		glfw.PollEvents()
		__frame()
	}

	__quit()
}

_quit :: proc() {
	glfw.SetWindowShouldClose(g_window.impl.handle, true)
}

__quit :: proc() {
	g_window.handler(Quit{})

	if .Save_Window_State in g_window.flags {
		hot: Hot

		x, y := glfw.GetWindowSize(g_window.impl.handle)
		hot.size = {int(x), int(y)}

		px, py := glfw.GetWindowPos(g_window.impl.handle)
		hot.pos = [2]int{int(px), int(py)}

		data, err := cbor.marshal(hot)
		assert(err == nil)

		persist_set(".window-state", data)
	}

	glfw.DestroyWindow(g_window.impl.handle)
	glfw.Terminate()
}

_wait_for_events :: proc() {
	glfw.WaitEvents()
}

_dpi :: proc() -> [2]f32 {
	x, y := glfw.GetWindowContentScale(g_window.impl.handle)
	return {x, y}
}

_frame_buffer_size :: proc() -> [2]f32 {
	w, h := glfw.GetFramebufferSize(g_window.impl.handle)
	return linalg.array_cast([2]i32{w, h}, f32)
}

_window_size :: proc() -> [2]f32 {
	w, h := glfw.GetWindowSize(g_window.impl.handle)
	return linalg.array_cast([2]i32{w, h}, f32)
}

@(private="file")
__frame :: proc() {
	context = g_window.ctx

	@static frame_time: time.Tick
	if frame_time == {} {
		frame_time = time.tick_now()
	}

	new_frame_time := time.tick_now()
	dt := time.tick_diff(frame_time, new_frame_time)
	frame_time = new_frame_time

	_gfx_frame()
	g_window.handler(Frame{ dt = clamp(f32(time.duration_seconds(dt)), 0, 1) })
	_gfx_frame_end()

	free_all(context.temp_allocator)
}

@(private="file")
__size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	context = g_window.ctx

	g_window.gfx.config.width  = u32(width)
	g_window.gfx.config.height = u32(height)
	wgpu.SurfaceConfigure(g_window.gfx.surface, &g_window.gfx.config)

	for r in g_window.gfx.renderers {
		r(Renderer_Resize{})
	}
	g_window.handler(Resize{})
	__frame()
}

@(private="file")
__error_callback :: proc "c" (code: i32, description: cstring) {
	context = g_window.ctx
	log.errorf("[nais][glfw]: %s", description)
}

_KEY_MOUSE_LEFT   :: glfw.MOUSE_BUTTON_LEFT
_KEY_MOUSE_RIGHT  :: glfw.MOUSE_BUTTON_RIGHT
_KEY_MOUSE_MIDDLE :: glfw.MOUSE_BUTTON_MIDDLE
_KEY_MOUSE_4      :: glfw.MOUSE_BUTTON_4
_KEY_MOUSE_5      :: glfw.MOUSE_BUTTON_5
_KEY_MOUSE_6      :: glfw.MOUSE_BUTTON_6
_KEY_MOUSE_7      :: glfw.MOUSE_BUTTON_7
_KEY_MOUSE_8      :: glfw.MOUSE_BUTTON_8

/* Named printable keys */
_KEY_SPACE         :: glfw.KEY_SPACE
_KEY_APOSTROPHE    :: glfw.KEY_APOSTROPHE
_KEY_COMMA         :: glfw.KEY_COMMA
_KEY_MINUS         :: glfw.KEY_MINUS
_KEY_PERIOD        :: glfw.KEY_PERIOD
_KEY_SLASH         :: glfw.KEY_SLASH
_KEY_SEMICOLON     :: glfw.KEY_SEMICOLON
_KEY_EQUAL         :: glfw.KEY_EQUAL
_KEY_LEFT_BRACKET  :: glfw.KEY_LEFT_BRACKET
_KEY_BACKSLASH     :: glfw.KEY_BACKSLASH
_KEY_RIGHT_BRACKET :: glfw.KEY_RIGHT_BRACKET
_KEY_GRAVE_ACCENT  :: glfw.KEY_GRAVE_ACCENT
_KEY_WORLD_1       :: glfw.KEY_WORLD_1
_KEY_WORLD_2       :: glfw.KEY_WORLD_2

/* Alphanumeric characters */
_KEY_0 :: glfw.KEY_0
_KEY_1 :: glfw.KEY_1
_KEY_2 :: glfw.KEY_2
_KEY_3 :: glfw.KEY_3
_KEY_4 :: glfw.KEY_4
_KEY_5 :: glfw.KEY_5
_KEY_6 :: glfw.KEY_6
_KEY_7 :: glfw.KEY_7
_KEY_8 :: glfw.KEY_8
_KEY_9 :: glfw.KEY_9

_KEY_A :: glfw.KEY_A
_KEY_B :: glfw.KEY_B
_KEY_C :: glfw.KEY_C
_KEY_D :: glfw.KEY_D
_KEY_E :: glfw.KEY_E
_KEY_F :: glfw.KEY_F
_KEY_G :: glfw.KEY_G
_KEY_H :: glfw.KEY_H
_KEY_I :: glfw.KEY_I
_KEY_J :: glfw.KEY_J
_KEY_K :: glfw.KEY_K
_KEY_L :: glfw.KEY_L
_KEY_M :: glfw.KEY_M
_KEY_N :: glfw.KEY_N
_KEY_O :: glfw.KEY_O
_KEY_P :: glfw.KEY_P
_KEY_Q :: glfw.KEY_Q
_KEY_R :: glfw.KEY_R
_KEY_S :: glfw.KEY_S
_KEY_T :: glfw.KEY_T
_KEY_U :: glfw.KEY_U
_KEY_V :: glfw.KEY_V
_KEY_W :: glfw.KEY_W
_KEY_X :: glfw.KEY_X
_KEY_Y :: glfw.KEY_Y
_KEY_Z :: glfw.KEY_Z


/** Function keys **/

/* Named non-printable keys */
_KEY_ESCAPE       :: glfw.KEY_ESCAPE
_KEY_ENTER        :: glfw.KEY_ENTER
_KEY_TAB          :: glfw.KEY_TAB
_KEY_BACKSPACE    :: glfw.KEY_BACKSPACE
_KEY_INSERT       :: glfw.KEY_INSERT
_KEY_DELETE       :: glfw.KEY_DELETE
_KEY_RIGHT        :: glfw.KEY_RIGHT
_KEY_LEFT         :: glfw.KEY_LEFT
_KEY_DOWN         :: glfw.KEY_DOWN
_KEY_UP           :: glfw.KEY_UP
_KEY_PAGE_UP      :: glfw.KEY_PAGE_UP
_KEY_PAGE_DOWN    :: glfw.KEY_PAGE_DOWN
_KEY_HOME         :: glfw.KEY_HOME
_KEY_END          :: glfw.KEY_END
_KEY_CAPS_LOCK    :: glfw.KEY_CAPS_LOCK
_KEY_SCROLL_LOCK  :: glfw.KEY_SCROLL_LOCK
_KEY_NUM_LOCK     :: glfw.KEY_NUM_LOCK
_KEY_PRINT_SCREEN :: glfw.KEY_PRINT_SCREEN
_KEY_PAUSE        :: glfw.KEY_PAUSE

/* Function keys */
_KEY_F1  :: glfw.KEY_F1
_KEY_F2  :: glfw.KEY_F2
_KEY_F3  :: glfw.KEY_F3
_KEY_F4  :: glfw.KEY_F4
_KEY_F5  :: glfw.KEY_F5
_KEY_F6  :: glfw.KEY_F6
_KEY_F7  :: glfw.KEY_F7
_KEY_F8  :: glfw.KEY_F8
_KEY_F9  :: glfw.KEY_F9
_KEY_F10 :: glfw.KEY_F10
_KEY_F11 :: glfw.KEY_F11
_KEY_F12 :: glfw.KEY_F12
_KEY_F13 :: glfw.KEY_F13
_KEY_F14 :: glfw.KEY_F14
_KEY_F15 :: glfw.KEY_F15
_KEY_F16 :: glfw.KEY_F16
_KEY_F17 :: glfw.KEY_F17
_KEY_F18 :: glfw.KEY_F18
_KEY_F19 :: glfw.KEY_F19
_KEY_F20 :: glfw.KEY_F20
_KEY_F21 :: glfw.KEY_F21
_KEY_F22 :: glfw.KEY_F22
_KEY_F23 :: glfw.KEY_F23
_KEY_F24 :: glfw.KEY_F24
_KEY_F25 :: glfw.KEY_F25

/* Keypad numbers */
_KEY_KP_0 :: glfw.KEY_KP_0
_KEY_KP_1 :: glfw.KEY_KP_1
_KEY_KP_2 :: glfw.KEY_KP_2
_KEY_KP_3 :: glfw.KEY_KP_3
_KEY_KP_4 :: glfw.KEY_KP_4
_KEY_KP_5 :: glfw.KEY_KP_5
_KEY_KP_6 :: glfw.KEY_KP_6
_KEY_KP_7 :: glfw.KEY_KP_7
_KEY_KP_8 :: glfw.KEY_KP_8
_KEY_KP_9 :: glfw.KEY_KP_9

/* Keypad named function keys */
_KEY_KP_DECIMAL  :: glfw.KEY_KP_DECIMAL
_KEY_KP_DIVIDE   :: glfw.KEY_KP_DIVIDE
_KEY_KP_MULTIPLY :: glfw.KEY_KP_MULTIPLY
_KEY_KP_SUBTRACT :: glfw.KEY_KP_SUBTRACT
_KEY_KP_ADD      :: glfw.KEY_KP_ADD
_KEY_KP_ENTER    :: glfw.KEY_KP_ENTER
_KEY_KP_EQUAL    :: glfw.KEY_KP_EQUAL

/* Modifier keys */
_KEY_LEFT_SHIFT    :: glfw.KEY_LEFT_SHIFT
_KEY_LEFT_CONTROL  :: glfw.KEY_LEFT_CONTROL
_KEY_LEFT_ALT      :: glfw.KEY_LEFT_ALT
_KEY_LEFT_SUPER    :: glfw.KEY_LEFT_SUPER
_KEY_RIGHT_SHIFT   :: glfw.KEY_RIGHT_SHIFT
_KEY_RIGHT_CONTROL :: glfw.KEY_RIGHT_CONTROL
_KEY_RIGHT_ALT     :: glfw.KEY_RIGHT_ALT
_KEY_RIGHT_SUPER   :: glfw.KEY_RIGHT_SUPER
_KEY_MENU          :: glfw.KEY_MENU

@(private="file")
__key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = g_window.ctx

	nkey    := Key(key)
	naction := Key_Action(action)

	if action == glfw.REPEAT {
		naction = .Pressed
	}

	g_window.handler(Input{
		key    = nkey,
		action = naction,
	})
}

@(private="file")
__mouse_button_callback :: proc "c" (window: glfw.WindowHandle, key, action, mods: i32) {
	__key_callback(window, key, 0, action, mods)
}

@(private="file")
__cursor_pos_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	context = g_window.ctx

	g_window.handler(Move{
		position = {x, y},
	})
}

@(private="file")
__scroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	context = g_window.ctx

	g_window.handler(Scroll{
		delta = {x, y},
	})
}

@(private="file")
__char_callback :: proc "c" (window: glfw.WindowHandle, ch: rune) {
	context = g_window.ctx

	g_window.handler(Text{
		ch = ch,
	})
}
