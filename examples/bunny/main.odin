/*
Bunnymark example, ported from [[ raylib; https://github.com/raysan5/raylib/blob/master/examples/textures/textures_bunnymark.c ]].
*/
package main

import      "core:fmt"
import      "core:log"
import      "core:math"
import      "core:math/linalg"
import      "core:math/rand"
import      "core:strconv"
import sa   "core:container/small_array"

import nais "../.."

MAX_BUNNIES  :: 50_000
BUNNY_WIDTH  :: 32
BUNNY_HEIGHT :: 32

Bunny :: struct {
	position: [2]f32,
	speed:    [2]f32,
	color:    u32,
}

// vec2f32_f32_vec3f32 :: proc(xy: [2]f32, z: f32) -> [3]f32 {
// 	return {xy.x, xy.y, z}
// }
//
// vec3 :: proc {
// 	vec2f32_f32_vec3f32,
// }

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	@(static)
	bunnies: ^sa.Small_Array(MAX_BUNNIES, Bunny)
	bunnies = new(type_of(bunnies^))

	@(static)
	bunny: nais.Sprite

	@(static) mouse_down: bool
	@(static) mouse_pos:  [2]f32

	nais.run("nais - bunnymark", {800, 450}, {.Windowed_Fullscreen}, proc(ev: nais.Event) {
		switch e in ev {
		case nais.Resize, nais.Text, nais.Scroll:
			log.info(e)

		case nais.Initialized:
			log.info("init")
			bunny = nais.load_sprite_from_memory(#load("../_resources/wabbit_alpha.png"), .PNG)

			nais.load_font_from_memory("default", #load("../_resources/NotoSans-500-100.ttf"))

			nais.background_set({245, 245, 245, 255})

		case nais.Input:
			if e.key == .Mouse_Left {
				mouse_down = e.action != .Released
			}

		case nais.Move:
			mouse_pos = linalg.array_cast(e.position, f32)

		case nais.Frame:
			if mouse_down {
				for _ in 0..<int(10000 * e.dt) {
					sa.append(bunnies, Bunny{
						position = mouse_pos,
						speed    = {
							f32(rand.int31_max(500)-250)/60,
							f32(rand.int31_max(500)-250)/60,
						},
                        color = transmute(u32)[4]u8{
                            u8(rand.int31_max(190) + 50),
                            u8(rand.int31_max(170) + 80),
                            u8(rand.int31_max(150) + 100),
                            255,
                        },
					})
				}
			}

			window_size := nais.window_size()

			for &bunny in bunnies.data[:bunnies.len] {
				bunny.position += bunny.speed * 20 * e.dt
				if (bunny.position.x + BUNNY_WIDTH / 2 > window_size.x) || (bunny.position.x + BUNNY_WIDTH / 2 < 0) {
					bunny.speed.x *= -1
				}
				if (bunny.position.y + BUNNY_HEIGHT / 2 > window_size.y) || (bunny.position.y + BUNNY_HEIGHT / 2 - 40 < 0) {
					bunny.speed.y *= -1
				}
			}

			for ebunny in bunnies.data[:bunnies.len] {
				nais.draw_sprite(bunny, ebunny.position, color=ebunny.color)
			}

			nais.draw_rectangle(0, {window_size.x, 40}, 0xFFFFFFFF)
			nais.draw_text(fmt.tprintf("bunnies: %v", bunnies.len), {120, 10}, size=20, color={0, 255, 0, 255}, align_v=.Top)

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
			nais.draw_text(fps, {10, 10}, size=20, color={0, 255, 0, 255}, align_v=.Top)
		}
	})
}
