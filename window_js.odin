//+private
package nais

import "core:fmt"
import "core:strings"
import "core:time"
import "core:log"
import "core:math/linalg"

import "vendor:wasm/js"
import "vendor:wgpu"

Impl :: struct {
	initialized: bool,
}

_run :: proc(title: string, size: [2]int, flags: Flags, handler: Event_Handler) {
	// glfw.SetScrollCallback(     g_window.impl.handle, __scroll_callback      )
	// glfw.SetCharCallback(       g_window.impl.handle, __char_callback        )
	// // // glfw.SetDropCallback(state.os.window, drop_callback)
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

	js.set_document_title(title)

	ok := js.add_event_listener("wgpu-canvas", .Pointer_Down, nil, __mouse_down_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Pointer_Up, nil, __mouse_up_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Pointer_Move, nil, __mouse_move_callback)
	assert(ok)
	ok  = js.add_event_listener("wgpu-canvas", .Touch_Move, nil, __mouse_move_callback)
	assert(ok)

	ok  = js.add_window_event_listener(.Resize, nil, __size_callback)
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

	log.debug("frame")
	_gfx_frame()
	g_window.handler(Frame{ dt = clamp(dt, 0, 1) })
	_gfx_frame_end()

	return true
}

_wait_for_events :: proc() {
	unimplemented()
}

_dpi :: proc() -> [2]f32 {
	dpi := js.device_pixel_ratio()
	return {f32(dpi), f32(dpi)}
}

_frame_buffer_size :: proc() -> [2]f32 {
	// if !g_window.impl.initialized {
		return {
			f32(g_window.gfx.config.width),
			f32(g_window.gfx.config.height)
		}// * dpi()
	// }
	// assert(g_window.impl.initialized)
	//
	// rect := js.get_bounding_client_rect("wgpu-canvas")
	// log.info(rect)
	// return {f32(rect.width), f32(rect.height)} * dpi()
}

_window_size :: proc() -> [2]f32 {
	// if !g_window.impl.initialized {
		return {
			f32(g_window.gfx.config.width ),
			f32(g_window.gfx.config.height),
		} / dpi()
	// }
	//
	// rect := js.get_bounding_client_rect("wgpu-canvas")
	// return {f32(rect.width), f32(rect.height)}
}

// @(private="file")
// __frame :: proc() {
// 	unimplemented()
// 	// @static frame_time: time.Tick
// 	// if frame_time == {} {
// 	// 	frame_time = time.tick_now()
// 	// }
// 	//
// 	// new_frame_time := time.tick_now()
// 	// dt := time.tick_diff(frame_time, new_frame_time)
// 	// frame_time = new_frame_time
// 	//
// 	// log.debug("frame")
// 	// _gfx_frame()
// 	// g_window.handler(Frame{ dt = f32(time.duration_seconds(dt)) })
// 	// _gfx_frame_end()
// 	//
// 	// free_all(context.temp_allocator)
// }
//
// @(private="file")
// __size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
// 	context = g_window.ctx
//
// 	g_window.gfx.config.width  = u32(width)
// 	g_window.gfx.config.height = u32(height)
// 	wgpu.SurfaceConfigure(g_window.gfx.surface, &g_window.gfx.config)
//
// 	for r in g_window.gfx.renderers {
// 		r(Renderer_Resize{})
// 	}
// 	g_window.handler(Resize{})
// 	__frame()
// }

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


// @(private="file")
// __error_callback :: proc "c" (code: i32, description: cstring) {
// 	context = g_window.ctx
// 	log.errorf("[nais][glfw]: %s", description)
// }

_KEY_MOUSE_LEFT   :: 0
_KEY_MOUSE_RIGHT  :: 1
_KEY_MOUSE_MIDDLE :: 2
_KEY_MOUSE_4      :: 3
_KEY_MOUSE_5      :: 4
_KEY_MOUSE_6      :: 5
_KEY_MOUSE_7      :: 6
_KEY_MOUSE_8      :: 7

/* Named printable keys */
_KEY_SPACE         :: 0
_KEY_APOSTROPHE    :: 0
_KEY_COMMA         :: 0
_KEY_MINUS         :: 0
_KEY_PERIOD        :: 0
_KEY_SLASH         :: 0
_KEY_SEMICOLON     :: 0
_KEY_EQUAL         :: 0
_KEY_LEFT_BRACKET  :: 0
_KEY_BACKSLASH     :: 0
_KEY_RIGHT_BRACKET :: 0
_KEY_GRAVE_ACCENT  :: 0
_KEY_WORLD_1       :: 0
_KEY_WORLD_2       :: 0

/* Alphanumeric characters */
_KEY_0 :: 0
_KEY_1 :: 0
_KEY_2 :: 0
_KEY_3 :: 0
_KEY_4 :: 0
_KEY_5 :: 0
_KEY_6 :: 0
_KEY_7 :: 0
_KEY_8 :: 0
_KEY_9 :: 0

_KEY_A :: 0
_KEY_B :: 0
_KEY_C :: 0
_KEY_D :: 0
_KEY_E :: 0
_KEY_F :: 0
_KEY_G :: 0
_KEY_H :: 0
_KEY_I :: 0
_KEY_J :: 0
_KEY_K :: 0
_KEY_L :: 0
_KEY_M :: 0
_KEY_N :: 0
_KEY_O :: 0
_KEY_P :: 0
_KEY_Q :: 0
_KEY_R :: 0
_KEY_S :: 0
_KEY_T :: 0
_KEY_U :: 0
_KEY_V :: 0
_KEY_W :: 0
_KEY_X :: 0
_KEY_Y :: 0
_KEY_Z :: 0


/** Function keys **/

/* Named non-printable keys */
_KEY_ESCAPE       :: 0
_KEY_ENTER        :: 0
_KEY_TAB          :: 0
_KEY_BACKSPACE    :: 0
_KEY_INSERT       :: 0
_KEY_DELETE       :: 0
_KEY_RIGHT        :: 0
_KEY_LEFT         :: 0
_KEY_DOWN         :: 0
_KEY_UP           :: 0
_KEY_PAGE_UP      :: 0
_KEY_PAGE_DOWN    :: 0
_KEY_HOME         :: 0
_KEY_END          :: 0
_KEY_CAPS_LOCK    :: 0
_KEY_SCROLL_LOCK  :: 0
_KEY_NUM_LOCK     :: 0
_KEY_PRINT_SCREEN :: 0
_KEY_PAUSE        :: 0

/* Function keys */
_KEY_F1  :: 0
_KEY_F2  :: 0
_KEY_F3  :: 0
_KEY_F4  :: 0
_KEY_F5  :: 0
_KEY_F6  :: 0
_KEY_F7  :: 0
_KEY_F8  :: 0
_KEY_F9  :: 0
_KEY_F10 :: 0
_KEY_F11 :: 0
_KEY_F12 :: 0
_KEY_F13 :: 0
_KEY_F14 :: 0
_KEY_F15 :: 0
_KEY_F16 :: 0
_KEY_F17 :: 0
_KEY_F18 :: 0
_KEY_F19 :: 0
_KEY_F20 :: 0
_KEY_F21 :: 0
_KEY_F22 :: 0
_KEY_F23 :: 0
_KEY_F24 :: 0
_KEY_F25 :: 0

/* Keypad numbers */
_KEY_KP_0 :: 0
_KEY_KP_1 :: 0
_KEY_KP_2 :: 0
_KEY_KP_3 :: 0
_KEY_KP_4 :: 0
_KEY_KP_5 :: 0
_KEY_KP_6 :: 0
_KEY_KP_7 :: 0
_KEY_KP_8 :: 0
_KEY_KP_9 :: 0

/* Keypad named function keys */
_KEY_KP_DECIMAL  :: 0
_KEY_KP_DIVIDE   :: 0
_KEY_KP_MULTIPLY :: 0
_KEY_KP_SUBTRACT :: 0
_KEY_KP_ADD      :: 0
_KEY_KP_ENTER    :: 0
_KEY_KP_EQUAL    :: 0

/* Modifier keys */
_KEY_LEFT_SHIFT    :: 0
_KEY_LEFT_CONTROL  :: 0
_KEY_LEFT_ALT      :: 0
_KEY_LEFT_SUPER    :: 0
_KEY_RIGHT_SHIFT   :: 0
_KEY_RIGHT_CONTROL :: 0
_KEY_RIGHT_ALT     :: 0
_KEY_RIGHT_SUPER   :: 0
_KEY_MENU          :: 0


// @(private="file")
// __key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
// 	context = g_window.ctx
//
// 	nkey    := Key(key)
// 	naction := Key_Action(action)
//
// 	g_window.handler(Input{
// 		key    = nkey,
// 		action = naction,
// 	})
// }
//
// @(private="file")
// __mouse_button_callback :: proc "c" (window: glfw.WindowHandle, key, action, mods: i32) {
// 	__key_callback(window, key, 0, action, mods)
// }
//
// @(private="file")
// __cursor_pos_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
// 	context = g_window.ctx
//
// 	g_window.handler(Move{
// 		position = {x, y},
// 	})
// }
//
// @(private="file")
// __scroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
// 	context = g_window.ctx
//
// 	g_window.handler(Scroll{
// 		delta = {x, y},
// 	})
// }
//
// @(private="file")
// __char_callback :: proc "c" (window: glfw.WindowHandle, ch: rune) {
// 	context = g_window.ctx
//
// 	g_window.handler(Text{
// 		ch = ch,
// 	})
// }

@(private="file")
__mouse_down_callback :: proc(e: js.Event) {
	context = g_window.ctx

	js.event_prevent_default()

	if e.data.mouse.button > 7 {
		log.warnf("mouse down callback with mouse button %v out of supported mouse button range", e.data.mouse.button)
		return
	}

	g_window.handler(Move{
		position = linalg.array_cast(e.data.mouse.offset, f64),
	})

	g_window.handler(Input{
		key    = Key(e.data.mouse.button),
		action = .Pressed,
	})
}

@(private="file")
__mouse_up_callback :: proc(e: js.Event) {
	context = g_window.ctx

	js.event_prevent_default()

	if e.data.mouse.button > 7 {
		log.warnf("mouse up callback with mouse button %v out of supported mouse button range", e.data.mouse.button)
		return
	}

	g_window.handler(Input{
		key    = Key(e.data.mouse.button),
		action = .Released,
	})
}

@(private="file")
__mouse_move_callback :: proc(e: js.Event) {
	context = g_window.ctx

	js.event_prevent_default()

	g_window.handler(Move{
		position = linalg.array_cast(e.data.mouse.offset, f64),
	})
}
