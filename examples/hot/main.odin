package main

import       "core:fmt"
import       "core:log"
import       "core:dynlib"
import       "core:encoding/cbor"

import nais "../../b"

main :: proc() {
	context.logger = log.create_console_logger(.Info)
	log.info("main")

	@(static) state: struct {
		acc:   f32,
		color: [4]u8,
	}
	state.color = {255, 0, 0, 255}

	nais.run("nais - hot", {800, 450}, {.Windowed_Fullscreen}, proc(ev: nais.Event) {
		switch e in ev {
		case nais.Serialize:
			err: cbor.Marshal_Error
			e.data^, err = cbor.marshal(state, cbor.ENCODE_SMALL, context.temp_allocator, context.temp_allocator)
			log.assertf(err == nil, "%v", err)

		case nais.Deserialize:
			err := cbor.unmarshal(string(e.data), &state)
			log.assertf(err == nil, "%v", err)

		case nais.Move, nais.Resize, nais.Text, nais.Scroll:

		case nais.Input:
			if e.key == .F5 && e.action == .Pressed {
				_, ok := dynlib.load_library("./game.dylib", true)
				log.assertf(ok, "failed to hot reload ;( %v", dynlib.last_error())
			}

		case nais.Initialized:
			nais.load_font_from_memory("default", #load("../_resources/NotoSans-500-100.ttf"))

			nais.background_set({245, 245, 245, 255})

		case nais.Frame:
			sz := nais.frame_buffer_size()
			nais.draw_text("Hellope!!!", pos=sz/2, color=state.color, align_h=.Center, align_v=.Middle)
			nais.draw_text(fmt.tprint(state.acc), 100, color=state.color)

			state.acc += e.dt
		}
	})
}
