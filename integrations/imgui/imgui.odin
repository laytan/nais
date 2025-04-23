package nais_integration_imgui

import nais  "../.."
import imgui "pkg:imgui"
import       "pkg:imgui/imgui_impl_wgpu"

init :: proc(init_info := imgui_impl_wgpu.INIT_INFO_DEFAULT, allocator := context.allocator) {
	init_info := init_info

	imgui.CHECKVERSION()
	io := imgui.GetIO()
	io.BackendPlatformName = "imgui_impl_nais"

	if init_info.Device == nil {
		init_info.Device = nais.g_window.gfx.config.device
	}

	if init_info.RenderTargetFormat == nil {
		init_info.RenderTargetFormat = nais.g_window.gfx.config.format
	}

	imgui_impl_wgpu.Init(init_info, allocator)

	append(&nais.g_window.gfx.renderers, _imgui_renderer)
}

event :: proc(event: nais.Event) {
	#partial switch e in event {
		case nais.Input:
			io := imgui.GetIO()

			if mb, ok := _imgui_mouse(e.key); ok {
				imgui.IO_AddMouseSourceEvent(io, .Mouse)
				imgui.IO_AddMouseButtonEvent(io, i32(mb), e.action == .Pressed)
			} else if ik := _imgui_key(e.key); ik != .None {
				imgui.IO_AddKeyEvent(io, _imgui_key(e.key), e.action == .Pressed)
			}

		case nais.Text:
			io := imgui.GetIO()
			imgui.IO_AddInputCharacter(io, u32(e.ch))

		case nais.Move:
			io := imgui.GetIO()
			imgui.IO_AddMouseSourceEvent(io, .Mouse)
			imgui.IO_AddMousePosEvent(io, f32(e.position.x), f32(e.position.y))

		case nais.Scroll:
			io := imgui.GetIO()
			imgui.IO_AddMouseWheelEvent(io, f32(e.delta.x), f32(e.delta.y))

		case nais.Frame:
			io := imgui.GetIO()
			io.DeltaTime               = e.dt
			io.DisplaySize             = nais.window_size()
			io.DisplayFramebufferScale = nais.dpi()
	}
}

_imgui_renderer :: proc(ev: nais.Renderer_Event) {
	switch e in ev {
	case nais.Renderer_Resize:

	case nais.Renderer_Flush:
		imgui_impl_wgpu.RenderDrawData(imgui.GetDrawData(), e.pass)

	case nais.Renderer_Frame:
		imgui_impl_wgpu.NewFrame()
	}
}

_imgui_mouse :: proc(key: nais.Key) -> (mb: imgui.MouseButton, ok: bool) {
	#partial switch key {
	case .Mouse_Left:    return .Left, true
	case .Mouse_Right:   return .Right, true
	case .Mouse_Middle:  return .Middle, true
	case .Mouse_4:       return imgui.MouseButton(3), true
	case .Mouse_5:       return imgui.MouseButton(4), true
	case .Mouse_6,
		 .Mouse_7,
		 .Mouse_8:       return nil, false

	case:                return nil, false
	}
}

_imgui_key :: proc(key: nais.Key) -> imgui.Key {
	switch key {
	case .Mouse_Left:    return .MouseLeft
	case .Mouse_Right:   return .MouseRight
	case .Mouse_Middle:  return .MouseMiddle
	case .Mouse_4:       return .MouseX1
	case .Mouse_5:       return .MouseX2
	case .Mouse_6,
		 .Mouse_7,
		 .Mouse_8:       return .None

	/* Named printable keys */
	case .Space:          return .Space
	case .Apostrophe:     return .Apostrophe
	case .Comma:          return .Comma
	case .Minus:          return .Minus
	case .Period:         return .Period
	case .Slash:          return .Slash
	case .Semicolon:      return .Semicolon
	case .Equal:          return .Equal
	case .Left_Bracket:   return .LeftBracket
	case .Backslash:      return .Backslash
	case .Right_Bracket:  return .RightBracket
	case .Grave_Accent:   return .GraveAccent
	case .World_1,
		 .World_2:        return .None

	/* Alphanumeric characters */
	case .N0:  return ._0
	case .N1:  return ._1
	case .N2:  return ._2
	case .N3:  return ._3
	case .N4:  return ._4
	case .N5:  return ._5
	case .N6:  return ._6
	case .N7:  return ._7
	case .N8:  return ._8
	case .N9:  return ._9

	case .A:  return .A
	case .B:  return .B
	case .C:  return .C
	case .D:  return .D
	case .E:  return .E
	case .F:  return .F
	case .G:  return .G
	case .H:  return .H
	case .I:  return .I
	case .J:  return .J
	case .K:  return .K
	case .L:  return .L
	case .M:  return .M
	case .N:  return .N
	case .O:  return .O
	case .P:  return .P
	case .Q:  return .Q
	case .R:  return .R
	case .S:  return .S
	case .T:  return .T
	case .U:  return .U
	case .V:  return .V
	case .W:  return .W
	case .X:  return .X
	case .Y:  return .Y
	case .Z:  return .Z

	/* Named non-printable keys */
	case .Escape:        return .Escape
	case .Enter:         return .Enter
	case .Tab:           return .Tab
	case .Backspace:     return .Backspace
	case .Insert:        return .Insert
	case .Delete:        return .Delete
	case .Right:         return .RightArrow
	case .Left:          return .LeftArrow
	case .Down:          return .DownArrow
	case .Up:            return .UpArrow
	case .Page_Up:       return .PageUp
	case .Page_Down:     return .PageDown
	case .Home:          return .Home
	case .End:           return .End
	case .Caps_Lock:     return .CapsLock
	case .Scroll_Lock:   return .ScrollLock
	case .Num_Lock:      return .NumLock
	case .Print_Screen:  return .PrintScreen
	case .Pause:         return .Pause

	/* Function keys */
	case .F1:   return .F1
	case .F2:   return .F2
	case .F3:   return .F3
	case .F4:   return .F4
	case .F5:   return .F5
	case .F6:   return .F6
	case .F7:   return .F7
	case .F8:   return .F8
	case .F9:   return .F9
	case .F10:  return .F10
	case .F11:  return .F11
	case .F12:  return .F12
	case .F13:  return .F13
	case .F14:  return .F14
	case .F15:  return .F15
	case .F16:  return .F16
	case .F17:  return .F17
	case .F18:  return .F18
	case .F19:  return .F19
	case .F20:  return .F20
	case .F21:  return .F21
	case .F22:  return .F22
	case .F23:  return .F23
	case .F24:  return .F24
	case .F25:  return .None

	/* Keypad numbers */
	case .KP_0: return .Keypad0
	case .KP_1: return .Keypad1
	case .KP_2: return .Keypad2
	case .KP_3: return .Keypad3
	case .KP_4: return .Keypad4
	case .KP_5: return .Keypad5
	case .KP_6: return .Keypad6
	case .KP_7: return .Keypad7
	case .KP_8: return .Keypad8
	case .KP_9: return .Keypad9

	/* Keypad named function keys */
	case .KP_Decimal:   return .KeypadDecimal
	case .KP_Divide:    return .KeypadDivide
	case .KP_Multiply:  return .KeypadMultiply
	case .KP_Subtract:  return .KeypadSubtract
	case .KP_Add:       return .KeypadAdd
	case .KP_Enter:     return .KeypadEnter
	case .KP_Equal:     return .KeypadEqual

	/* Modifier keys */
	case .Left_Shift:     return .LeftShift
	case .Left_Control:   return .LeftCtrl
	case .Left_Alt:       return .LeftAlt
	case .Left_Super:     return .LeftSuper
	case .Right_Shift:    return .RightShift
	case .Right_Control:  return .RightCtrl
	case .Right_Alt:      return .RightAlt
	case .Right_Super:    return .RightSuper
	case .Menu:           return .Menu
	case:                 return .None
	}
}
