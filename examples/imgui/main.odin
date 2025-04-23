package main

import            "core:log"

import imgui      "pkg:imgui"

import nais       "../.."
import nais_imgui "../../integrations/imgui"

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	nais.run("Dear Imgui", {1920, 1080}, {.VSync, .Low_Power, .Windowed_Fullscreen}, proc(event: nais.Event) {
		nais_imgui.event(event)

		#partial switch e in event {
		case nais.Initialized:
			imgui.CHECKVERSION()
			imgui.CreateContext()

			io := imgui.GetIO()
			io.ConfigFlags += {.NavEnableKeyboard, .DockingEnable}
			imgui.StyleColorsDark()

			nais_imgui.init()

		case nais.Frame:
			nais.background_set({0, 0, 0, 1})

			imgui.NewFrame()

			imgui.ShowDemoWindow()

			imgui.Render()
		}
	})
}

