package main

import "core:fmt"
import "core:log"
import "core:math/linalg"

import nais "../.."

size := [2]f32{360, 360}
cursor: [2]f32
scroll: [2]f32
pos:    [2]f32
pointer: bool
debug: bool
camera := nais.Camera{
	zoom = 1,
}

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	nais.run("Hellope", linalg.to_int(size), {.Save_Window_State, .VSync, .Low_Power, .Windowed_Fullscreen}, proc(event: nais.Event) {
		#partial switch e in event {
		case nais.Initialized:
			size = nais.window_size()
			nais.load_font_from_memory("Default", #load("../_resources/Calistoga-Regular.ttf"))
			
		case nais.Resize:
			size = nais.window_size()

		case nais.Frame:
			nais.background_set({1, 1, 1, 1})

			nais.draw_text("Hellope", pos=size/2, color={0, 0, 0, 255}, align_h=.Right, align_v=.Top)
		}
	})
}
