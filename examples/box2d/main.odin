/*
The bunnymark example with actual physics!
*/
package main

import      "core:dynlib"
import      "core:fmt"
import      "core:log"
import      "core:math"
import      "core:math/linalg"
import      "core:math/rand"
import      "core:strconv"
import sa   "core:container/small_array"
import "core:encoding/cbor"

import b2   "vendor:box2d"

import nais "../../b"

MAX_BUNNIES  :: 50_000
BUNNY_WIDTH  :: 16
BUNNY_HEIGHT :: 32

Bunny :: struct {
	body:     b2.BodyId,
	color:    u32,
}

Bunny_Ser :: struct {
	color:            u32,
	transform:        b2.Transform,
	angular_damping:  f32,
	angular_velocity: f32,
	linear_velocity:  [2]f32,
}

Bound :: struct {
	size:  [2]f32,
	shape: b2.ShapeId,
}

// hot reload exe keeps track and recompiles the game into a dll
// retrieve event handler, trigger "serialize"
// set event handler to one from dll, trigger "deserialize"

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	@(static)
	state: struct {
		bunnies:     sa.Small_Array(MAX_BUNNIES, Bunny) `cbor:"-"`,
		bunnies_ser: [dynamic]Bunny_Ser,
		bunny:       nais.Sprite,
		mouse_down:  bool,
		mouse_pos:   [2]f32,
		world_id:    b2.WorldId `cbor:"-"`,
		bounds:      [4]Bound   `cbor:"-"`,
		version:     int,
	}

	b2.SetLengthUnitsPerMeter(BUNNY_WIDTH)

	world_def := b2.DefaultWorldDef()
	world_def.gravity = 0

	state.world_id = b2.CreateWorld(world_def)

	assert(state.bunnies.len == 0)

	for &b in state.bounds {
		body_def  := b2.DefaultBodyDef()
		body_id   := b2.CreateBody(state.world_id, body_def)
		shape_def := b2.DefaultShapeDef()

		shape_def.restitution = 1
		b.shape = b2.CreatePolygonShape(body_id, shape_def, b2.MakeBox(1, 1))
	}

	update_bounds :: proc() {
		sz := nais.window_size()

		state.bounds[0].size = {20, sz.y}
		state.bounds[1].size = {20, sz.y}
		state.bounds[2].size = {sz.x, 20}
		state.bounds[3].size = {sz.x, 20}

		b2.Body_SetTransform(b2.Shape_GetBody(state.bounds[0].shape), {-10,     sz.y/2 }, b2.Rot_identity)
		b2.Body_SetTransform(b2.Shape_GetBody(state.bounds[1].shape), {sz.x+10, sz.y/2 }, b2.Rot_identity)
		b2.Body_SetTransform(b2.Shape_GetBody(state.bounds[2].shape), {sz.x/2,  -10    }, b2.Rot_identity)
		b2.Body_SetTransform(b2.Shape_GetBody(state.bounds[3].shape), {sz.x/2,  sz.y+10}, b2.Rot_identity)

		b2.Shape_SetPolygon(state.bounds[0].shape, b2.MakeBox(20, sz.y))
		b2.Shape_SetPolygon(state.bounds[1].shape, b2.MakeBox(20, sz.y))
		b2.Shape_SetPolygon(state.bounds[2].shape, b2.MakeBox(sz.x, 20))
		b2.Shape_SetPolygon(state.bounds[3].shape, b2.MakeBox(sz.x, 20))
	}

	nais.run("nais - box2d", {800, 450}, {.VSync, .Windowed_Fullscreen}, proc(ev: nais.Event) {
		#partial switch e in ev {
		case nais.Serialize:
			context.allocator = context.temp_allocator

			for ebunny in state.bunnies.data[:state.bunnies.len] {
				append(&state.bunnies_ser, Bunny_Ser{
					color            = ebunny.color,
					transform        = b2.Body_GetTransform(ebunny.body),
					angular_damping  = b2.Body_GetAngularDamping(ebunny.body),
					angular_velocity = b2.Body_GetAngularVelocity(ebunny.body),
					linear_velocity  = b2.Body_GetLinearVelocity(ebunny.body),
				})
			}

			data, err := cbor.marshal(state)
			assert(err == nil)
			e.data^ = data

		case nais.Deserialize:
			assert(state.bunnies.len == 0)
			assert(len(state.bunnies_ser) == 0)

			err := cbor.unmarshal(string(e.data), &state)
			assert(err == nil)

			log.info(len(state.bunnies_ser))

			for ebunny in state.bunnies_ser {
				bunny_extent := b2.Vec2{.5 * BUNNY_WIDTH, .5 * BUNNY_HEIGHT}
				// These polygons are centered on the origin and when they are added to a body they
				// will be centered on the body position.
				bunny_polygon := b2.MakeBox(bunny_extent.x, bunny_extent.y)

				body_def := b2.DefaultBodyDef()
				body_def.type            = .dynamicBody
				body_def.position        = ebunny.transform.p
				body_def.rotation        = ebunny.transform.q
				body_def.linearVelocity  = ebunny.linear_velocity
				body_def.angularDamping  = ebunny.angular_damping
				body_def.angularVelocity = ebunny.angular_velocity
				body := b2.CreateBody(state.world_id, body_def)

				shape_def := b2.DefaultShapeDef()
				shape_def.restitution = 1
				_ = b2.CreatePolygonShape(body, shape_def, bunny_polygon)

				sa.append(&state.bunnies, Bunny{
					body  = body,
					color = ebunny.color,
				})
			}
			delete(state.bunnies_ser)
			state.bunnies_ser = {}

			update_bounds()

		case nais.Initialized:
			update_bounds()

			state.bunny = nais.load_sprite_from_memory(#load("../_resources/wabbit_alpha.png"), .PNG)

			nais.load_font_from_memory("default", #load("../_resources/NotoSans-500-100.ttf"))

			nais.background_set({245, 245, 245, 255})

		case nais.Resize:
			update_bounds()

		case nais.Input:
			if e.key == .Mouse_Left {
				state.mouse_down = e.action != .Released
			} else if e.key == .F5 && e.action == .Pressed {
				log.info("hot reloading")
				version := state.version
				state.version += 1
				_, ok := dynlib.load_library(fmt.tprintf("./game%v.dylib", version), true)
				log.assertf(ok, "failed to hot reload ;( %v", dynlib.last_error())
			}

		case nais.Move:
			state.mouse_pos = linalg.array_cast(e.position, f32)

		case nais.Frame:
			nais.background_set({0, 0, 0, 255})

			b2.World_Step(state.world_id, e.dt, 4)

			if state.mouse_down {
				bunny_extent := b2.Vec2{.5 * BUNNY_WIDTH, .5 * BUNNY_HEIGHT}
				// These polygons are centered on the origin and when they are added to a body they
				// will be centered on the body position.
				bunny_polygon := b2.MakeBox(bunny_extent.x, bunny_extent.y)

				body_def := b2.DefaultBodyDef()
				body_def.type = .dynamicBody
				body_def.position = state.mouse_pos
				body_def.linearVelocity = {
					f32(rand.int31_max(2000)-1000)/5,
					f32(rand.int31_max(2000)-1000)/5,
				}
				body := b2.CreateBody(state.world_id, body_def)

				shape_def := b2.DefaultShapeDef()
				shape_def.restitution = 1
				_ = b2.CreatePolygonShape(body, shape_def, bunny_polygon)

				sa.append(&state.bunnies, Bunny{
					body = body,
					color = transmute(u32)[4]u8{
						u8(rand.int31_max(190) + 50),
						u8(rand.int31_max(170) + 80),
						u8(rand.int31_max(150) + 100),
						255,
					},
				})
			}

			window_size := nais.window_size()

			for ebunny in state.bunnies.data[:state.bunnies.len] {
				position := b2.Body_GetPosition(ebunny.body)
				rotation := b2.Body_GetRotation(ebunny.body)
				radians  := b2.Rot_GetAngle(rotation)

				nais.draw_sprite(state.bunny, position, rotation=radians, color=ebunny.color, anchor=.5)
			}

			// for bound in bounds {
			// 	body     := b2.Shape_GetBody(bound.shape)
			// 	position := b2.Body_GetPosition(body)
			// 	log.info(position, bound.size)
			// 	nais.draw_rectangle(position, bound.size, 0xcccccccc, anchor=.5)
			// }

			bunnies_text := fmt.tprintf("bunnies: %v", state.bunnies.len)
			measurement  := nais.measure_text(bunnies_text, {10, 10}, size=32, align_v=.Top)
			nais.draw_rectangle(0, {window_size.x, measurement.max.y-measurement.min.y}, 0xFFFFFFFF)
			nais.draw_text(bunnies_text, {10, 10}, size=32, color={0, 0, 0, 255}, align_v=.Top)

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
			buf[0] = 'f'
			buf[1] = 'p'
			buf[2] = 's'
			buf[3] = ':'
			buf[4] = ' '
			fps_len := len(strconv.itoa(buf[5:], int(math.round(len(frame_times)/frame_time))))
			nais.draw_text(string(buf[:fps_len+5]), {measurement.max.x + 32, 10}, size=32, color={0, 0, 0, 255}, align_v=.Top)
		}
	})
}