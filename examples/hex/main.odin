package main

import      "core:log"

import nais "../.."

W :: 65
H :: 89

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	@(static)
	g: struct {
		grass: nais.Sprite,
		lava:  nais.Sprite,
	}

	nais.run("nais - box2d", {800, 450}, {.VSync}, proc(ev: nais.Event) {
		#partial switch e in ev {
		case nais.Initialized:
			g.grass = nais.load_sprite_from_memory(#load("../_resources/hex/tileGrass.png"), .PNG)
			g.lava  = nais.load_sprite_from_memory(#load("../_resources/hex/tileLava.png"), .PNG)

			nais.background_set({0, 22, 180, 255})

		case nais.Frame:
			pos := [2]f32{W*2, H*2}
			for i in f32(0)..<5 {
				nais.draw_sprite(g.grass, pos + {W*i, 0})
			}

			pos += {W/2, H/2}
			for i in f32(0)..<5 {
				nais.draw_sprite(g.grass, pos + {W*i, 0})
			}

			// pos += {W, 0}
			// nais.draw_sprite(g.grass, pos)
			//
			// pos += {W, 0}
			// nais.draw_sprite(g.grass, pos)
			//
			// pos += {W, 0}
			// nais.draw_sprite(g.grass, pos)
			//
			// pos += {W/2, H/2}
			// nais.draw_sprite(g.grass, pos)
		}
	})
}
