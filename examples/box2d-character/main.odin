// Box2D character sample, original is at https://github.com/erincatto/box2d/blob/main/samples/sample_character.cpp
package main

import            "core:log"
import            "core:strconv"
import            "core:math"
import            "core:strings"
import            "core:math/linalg"

import b2         "vendor:box2d"

import imgui      "pkg:imgui"

import nais       "../.."
import nais_imgui "../../integrations/imgui"

THICKNESS :: 2

rgba :: proc(c: b2.HexColor) -> [4]f32 {
	argb := transmute([4]u8)cast(u32)transmute(u32be)c
	assert(argb[0] == 0)
	return {f32(argb[1])/255, f32(argb[2])/255, f32(argb[3])/255, 1}
}

rgba8 :: proc(c: b2.HexColor) -> [4]u8 {
	argb := transmute([4]u8)cast(u32)transmute(u32be)c
	assert(argb[0] == 0)
	return {argb[1], argb[2], argb[3], 1}
}

Vec :: b2.Vec2

Settings :: struct {
	restart:        bool,
	draw_joints:    bool,
	pause:          bool,
	single_step:    bool,
	hertz:          f32,
	sub_step_count: i32,
}

settings_init :: proc(s: ^Settings) {
	s.hertz          = 60
	s.sub_step_count = 4
}

g_camera: nais.Camera

PLANE_CAPACITY     :: 8
ELEVATOR_BASE      :: Vec{112., 10.}
ELEVATOR_AMPLITUDE :: 4.

Shape_User_Data :: struct {
	max_push:      f32,
	clip_velocity: bool,
}

Collision_Bits :: bit_set[enum {Static, Mover, Dynamic, Debris}; u64]

Pogo_Shape :: enum i32 {
	Point,
	Circle,
	Segment,
}

Cast_Result :: struct {
	point:    Vec,
	body_id:  b2.BodyId,
	fraction: f32,
	hit:      bool,
}

cast_callback :: proc "c" (shape_id: b2.ShapeId, point: Vec, normal: Vec, fraction: f32, ctx: rawptr) -> f32 {
	result := (^Cast_Result)(ctx)
	result.point    = point
	result.body_id  = b2.Shape_GetBody(shape_id)
	result.fraction = fraction
	result.hit      = true
	return fraction
}

Mover :: struct {
	world_id:           b2.WorldId,

	jump_speed:         f32,
	max_speed:          f32,
	min_speed:          f32,
	stop_speed:         f32,
	accelerate:         f32,
	air_steer:          f32,
	friction:           f32,
	gravity:            f32,
	pogo_hertz:         f32,
	pogo_damping_ratio: f32,
	pogo_shape:         Pogo_Shape,
	transform:          b2.Transform,
	velocity:           Vec,
	capsule:            b2.Capsule,
	elevator_id:        b2.BodyId,
	ball_id:            b2.ShapeId,
	friendly_shape:     Shape_User_Data,
	elevator_shape:     Shape_User_Data,
	planes:             [PLANE_CAPACITY]b2.CollisionPlane,
	plane_count:        int,
	total_iterations:   int,
	pogo_velocity:      f32,
	time:               f32,
	on_ground:          bool,
	jump_released:      bool,
	lock_camera:        bool,
}

mover_init :: proc(m: ^Mover, settings: ^Settings) {
	m.jump_speed         = 10.
	m.max_speed          = 6.
	m.min_speed          = .1
	m.stop_speed         = 3.
	m.accelerate         = 20.
	m.air_steer          = .2
	m.friction           = 8.
	m.gravity            = 30.
	m.pogo_hertz         = 5.
	m.pogo_damping_ratio = .8

	if !settings.restart {
		g_camera.target   = Vec{20., 9.}
		g_camera.zoom     = 20
		g_camera.invert_y = true
	}

	m.transform = {{2., 8.}, b2.Rot_identity}
	m.velocity  = 0
	m.capsule   = {{0., -.5}, {0., .5}, .3}

	ground_id_1: b2.BodyId
	{
		body_def := b2.DefaultBodyDef()
		body_def.position = 0
		ground_id_1 = b2.CreateBody(m.world_id, body_def)

		path :: "M 2.6458333,201.08333 H 293.68751 v -47.625 h -2.64584 l -10.58333,7.9375 -13.22916,7.9375 -13.24648,5.29167 "   +
				"-31.73269,7.9375 -21.16667,2.64583 -23.8125,10.58333 H 142.875 v -5.29167 h -5.29166 v 5.29167 H 119.0625 v "    +
				"-2.64583 h -2.64583 v -2.64584 h -2.64584 v -2.64583 H 111.125 v -2.64583 H 84.666668 v -2.64583 h -5.291666 v " +
				"-2.64584 h -5.291667 v -2.64583 H 68.791668 V 174.625 h -5.291666 v -2.64584 H 52.916669 L 39.6875,177.27083 H " +
				"34.395833 L 23.8125,185.20833 H 15.875 L 5.2916669,187.85416 V 153.45833 H 2.6458333 v 47.625"

		points: [64]Vec

		offset := Vec{-50., -200.}
		scale  := f32(.2)

		count := parse_path(path, offset, points[:], scale)

		chain_def := b2.DefaultChainDef()
		chain_def.points = raw_data(&points)
		chain_def.count = i32(count)
		chain_def.isLoop = true

		_ = b2.CreateChain(ground_id_1, chain_def)
	}

	ground_id_2: b2.BodyId
	{
		body_def := b2.DefaultBodyDef()
		body_def.position = {98., 0.}
		ground_id_2 = b2.CreateBody(m.world_id, body_def)


		path :: "M 2.6458333,201.08333 H 293.68751 l 0,-23.8125 h -23.8125 l 21.16667,21.16667 h -23.8125 l -39.68751,-13.22917 " +
				"-26.45833,7.9375 -23.8125,2.64583 h -13.22917 l -0.0575,2.64584 h -5.29166 v -2.64583 l -7.86855,-1e-5 "         +
				"-0.0114,-2.64583 h -2.64583 l -2.64583,2.64584 h -7.9375 l -2.64584,2.64583 -2.58891,-2.64584 h -13.28609 v "    +
				"-2.64583 h -2.64583 v -2.64584 l -5.29167,1e-5 v -2.64583 h -2.64583 v -2.64583 l -5.29167,-1e-5 v -2.64583 h "  +
				"-2.64583 v -2.64584 h -5.291667 v -2.64583 H 92.60417 V 174.625 h -5.291667 v -2.64584 l -34.395835,1e-5 "       +
				"-7.9375,-2.64584 -7.9375,-2.64583 -5.291667,-5.29167 H 21.166667 L 13.229167,158.75 5.2916668,153.45833 H "      +
				"2.6458334 l -10e-8,47.625"

		points: [64]Vec

		offset := Vec{0., -200.}
		scale  := f32(.2)

		count := parse_path(path, offset, points[:], scale)

		chain_def := b2.DefaultChainDef()
		chain_def.points = raw_data(&points)
		chain_def.count = i32(count)
		chain_def.isLoop = true

		_ = b2.CreateChain(ground_id_2, chain_def)
	}

	{
		box := b2.MakeBox(.5, .125)

		shape_def := b2.DefaultShapeDef()

		joint_def := b2.DefaultRevoluteJointDef()
		joint_def.maxMotorTorque = 10.
		joint_def.enableMotor = true
		joint_def.hertz = 3.
		joint_def.dampingRatio = .8
		joint_def.enableSpring = true

		x_base := f32(48.7)
		y_base := f32(9.2)
		count  := 50
		prev_body_id := ground_id_1
		for i in 0..<count {
			body_def := b2.DefaultBodyDef()
			body_def.type = .dynamicBody
			body_def.position = {x_base + .5 + 1. * f32(i), y_base}
			body_def.angularDamping = .2
			body_id := b2.CreateBody(m.world_id, body_def)
			_ = b2.CreatePolygonShape(body_id, shape_def, box)

			pivot := Vec{x_base + 1. * f32(i), y_base}
			joint_def.bodyIdA = prev_body_id
			joint_def.bodyIdB = body_id
			joint_def.localAnchorA = b2.Body_GetLocalPoint(joint_def.bodyIdA, pivot)
			joint_def.localAnchorB = b2.Body_GetLocalPoint(joint_def.bodyIdB, pivot)
			_ = b2.CreateRevoluteJoint(m.world_id, joint_def)

			prev_body_id = body_id
		}

		pivot := Vec{x_base + 1. * f32(count), y_base}
		joint_def.bodyIdA = prev_body_id
		joint_def.bodyIdB = ground_id_2
		joint_def.localAnchorA = b2.Body_GetLocalPoint(joint_def.bodyIdA, pivot)
		joint_def.localAnchorB = b2.Body_GetLocalPoint(joint_def.bodyIdB, pivot)
		_ = b2.CreateRevoluteJoint(m.world_id, joint_def)
	}

	{
		body_def := b2.DefaultBodyDef()
		body_def.position = {32., 4.5}

		shape_def := b2.DefaultShapeDef()
		m.friendly_shape.max_push = .025
		m.friendly_shape.clip_velocity = false

		shape_def.filter = {
			transmute(u64) Collision_Bits{.Mover},
			transmute(u64)~Collision_Bits{},
			0,
		}
		shape_def.userData = &m.friendly_shape
		body_id := b2.CreateBody(m.world_id, body_def)
		_ = b2.CreateCapsuleShape(body_id, shape_def, m.capsule)
	}

	// Debris.
	{
		body_def := b2.DefaultBodyDef()
		body_def.type = .dynamicBody
		body_def.position = {7., 7.}
		body_id := b2.CreateBody(m.world_id, body_def)

		shape_def := b2.DefaultShapeDef()
		shape_def.filter = {
			transmute(u64) Collision_Bits{.Debris},
			transmute(u64)~Collision_Bits{},
			0,
		}
		shape_def.material.restitution = .7
		shape_def.material.rollingResistance = .2

		circle := b2.Circle{b2.Vec2_zero, .3}
		m.ball_id = b2.CreateCircleShape(body_id, shape_def, circle)
	}

	// Elevator.
	{
		body_def := b2.DefaultBodyDef()
		body_def.type = .kinematicBody
		body_def.position = {ELEVATOR_BASE.x, ELEVATOR_BASE.y - ELEVATOR_AMPLITUDE}
		m.elevator_id = b2.CreateBody(m.world_id, body_def)

		m.elevator_shape = {
			max_push      = .1,
			clip_velocity = true,
		}
		shape_def := b2.DefaultShapeDef()
		shape_def.filter = {
			transmute(u64) Collision_Bits{.Dynamic},
			transmute(u64)~Collision_Bits{},
			0,
		}
		shape_def.userData = &m.elevator_shape

		box := b2.MakeBox(2., .1)
		_ = b2.CreatePolygonShape(m.elevator_id, shape_def, box)
	}

	m.total_iterations = 0
	m.pogo_velocity    = 0
	m.on_ground        = false
	m.jump_released    = true
	m.lock_camera      = true
	m.plane_count      = 0
	m.time             = 0
}

solve_move :: proc(m: ^Mover, time_step, throttle: f32) {
	// Friction
	speed := b2.Length(m.velocity)
	if speed < m.min_speed {
		m.velocity = 0
	} else if m.on_ground {
		// Linear damping above stop_speed and fixed reduction below stop_speed
		control := speed < m.stop_speed ? m.stop_speed : speed

		// friction has units of 1/time
		drop := control * m.friction * time_step
		new_speed := max(0, speed - drop)
		m.velocity *= new_speed / speed
	}

	desired_velocity := Vec{m.max_speed * throttle, 0.}
	desired_speed, desired_direction := b2.GetLengthAndNormalize(desired_velocity)

	desired_speed = min(desired_speed, m.max_speed)

	if m.on_ground {
		m.velocity.y = 0
	}

	// Accelerate
	current_speed := b2.Dot(m.velocity, desired_direction)
	add_speed := desired_speed - current_speed
	if add_speed > 0 {
		steer := m.on_ground ? 1. : m.air_steer
		accel_speed := steer * m.accelerate * m.max_speed * time_step
		accel_speed = min(accel_speed, add_speed)

		m.velocity += accel_speed * desired_direction
	}

	m.velocity.y -= m.gravity * time_step

	pogo_rest_length := 3. * m.capsule.radius
	ray_length := pogo_rest_length + m.capsule.radius
	origin := b2.TransformPoint(m.transform, m.capsule.center1)
	circle := b2.Circle{origin, .5 * m.capsule.radius}
	segment_offset := Vec{.75 * m.capsule.radius, 0.}
	segment := b2.Segment{ origin - segment_offset, origin + segment_offset }

	proxy: b2.ShapeProxy
	translation: Vec
	pogo_filter := b2.QueryFilter{
		transmute(u64)Collision_Bits{.Mover},
		transmute(u64)Collision_Bits{.Static, .Dynamic},
	}
	cast_result: Cast_Result

	switch m.pogo_shape {
	case .Point:
		proxy = b2.MakeProxy({origin}, 0)
		translation = {0, -ray_length}
	case .Circle:
		proxy = b2.MakeProxy({origin}, circle.radius)
		translation = {0, -ray_length + circle.radius}
	case .Segment:
		proxy = b2.MakeProxy({segment.point1, segment.point2}, 0)
		translation = {0, -ray_length}
	}

	_ = b2.World_CastShape(m.world_id, proxy, translation, pogo_filter, cast_callback, &cast_result)

	// Avoid snapping to ground if still going up
	if !m.on_ground {
		m.on_ground = cast_result.hit && m.velocity.y <= .01
	} else {
		m.on_ground = cast_result.hit
	}

	if !cast_result.hit {
		m.pogo_velocity = 0

		delta := translation
		nais.draw_segment(origin, origin + delta, rgba(b2.HexColor.Gray), pixel_to_world(THICKNESS))

		switch m.pogo_shape {
		case .Point:
			sz := pixel_to_world(10)
			nais.draw_rectangle(origin + delta - sz * .5, sz, rgba(b2.HexColor.Gray), 0)
		case .Circle:
			nais.draw_circle_outline(origin + delta, circle.radius, rgba(b2.HexColor.Gray), pixel_to_world(THICKNESS))
		case .Segment:
			nais.draw_segment(segment.point1 + delta, segment.point2 + delta, rgba(b2.HexColor.Gray), pixel_to_world(THICKNESS))
		}
	} else {
		pogo_current_length := cast_result.fraction * ray_length

		zeta   := m.pogo_damping_ratio
		hertz  := m.pogo_hertz
		omega  := 2. * b2.PI * hertz
		omegaH := omega * time_step

		m.pogo_velocity = (m.pogo_velocity - omega * omegaH * (pogo_current_length - pogo_rest_length)) / (1. + 2. * zeta * omegaH + omegaH * omegaH)

		delta := cast_result.fraction * translation
		nais.draw_segment(origin, origin + delta, rgba(b2.HexColor.Gray), pixel_to_world(THICKNESS))

		switch m.pogo_shape {
		case .Point:
			sz := pixel_to_world(10)
			nais.draw_rectangle(origin + delta - sz * .5, sz, rgba(b2.HexColor.Plum), 0)
		case .Circle:
			nais.draw_circle_outline(origin + delta, circle.radius, rgba(b2.HexColor.Plum), pixel_to_world(THICKNESS))
		case .Segment:	
			nais.draw_segment(segment.point1 + delta, segment.point2 + delta, rgba(b2.HexColor.Plum), pixel_to_world(THICKNESS))
		}

		b2.Body_ApplyForce(cast_result.body_id, {0., -50.}, cast_result.point, true)
	}

	target := m.transform.p + time_step * m.velocity + time_step * m.pogo_velocity * Vec{0., 1.}

	// Mover overlap filter
	collide_filter := b2.QueryFilter{
		transmute(u64)Collision_Bits{.Mover},
		transmute(u64)Collision_Bits{.Static, .Dynamic, .Mover},
	}

	// Movers don't sweep against other movers, allows for soft collision
	cast_filter := b2.QueryFilter{
		transmute(u64)Collision_Bits{.Mover},
		transmute(u64)Collision_Bits{.Static, .Dynamic},
	}

	m.total_iterations = 0
	tolerance := f32(.01)

	for iteration in 1..=5 {
		m.plane_count = 0

		mover: b2.Capsule
		mover.center1 = b2.TransformPoint(m.transform, m.capsule.center1)
		mover.center2 = b2.TransformPoint(m.transform, m.capsule.center2)
		mover.radius = m.capsule.radius

		b2.World_CollideMover(m.world_id, mover, collide_filter, plane_result_fcn, m)
		result := b2.SolvePlanes(target, m.planes[:m.plane_count])

		m.total_iterations += int(result.iterationCount)

		mover_translation := result.position - m.transform.p

		fraction := b2.World_CastMover(m.world_id, mover, mover_translation, cast_filter)

		delta := fraction * mover_translation
		m.transform.p += delta

		if b2.LengthSquared(delta) < tolerance * tolerance {
			break
		}
	}

	m.velocity = b2.ClipVector(m.velocity, m.planes[:m.plane_count])
}

update_gui :: proc(m: ^Mover) {
	height := f32(350.)
	imgui.SetNextWindowPos({10., nais.window_size().y - height - 25.}, .Once)
	imgui.SetNextWindowSize({340., height})

	if imgui.Begin("Mover") {
		defer imgui.End()

		{
			imgui.PushItemWidth(240.)
			defer imgui.PopItemWidth()

			imgui.SliderFloat("Jump Speed", &m.jump_speed, 0., 40., "%.0f")
			imgui.SliderFloat("Min Speed", &m.min_speed, 0., 1., "%.2f")
			imgui.SliderFloat("Max Speed", &m.max_speed, 0., 20., "%.0f")
			imgui.SliderFloat("Stop Speed", &m.stop_speed, 0., 10., "%.1f")
			imgui.SliderFloat("Accelerate", &m.accelerate, 0., 100., "%.0f")
			imgui.SliderFloat("Friction", &m.friction, 0., 10., "%.1f")
			imgui.SliderFloat("Gravity", &m.gravity, 0., 100., "%.1f")
			imgui.SliderFloat("Air Steer", &m.air_steer, 0., 1., "%.2f")
			imgui.SliderFloat("Pogo Hertz", &m.pogo_hertz, 0., 30., "%.0f")
			imgui.SliderFloat("Pogo Damping", &m.pogo_damping_ratio, 0., 4., "%.1f")

			imgui.Separator()

			imgui.SliderFloat("Zoom", &g_camera.zoom, -100, 100, "%.0f")
		}

		imgui.Separator()

		imgui.Text("Pogo Shape")
		imgui.RadioButtonIntPtr("Point",   cast(^i32)&m.pogo_shape, cast(i32)Pogo_Shape.Point)
		imgui.SameLine()
		imgui.RadioButtonIntPtr("Circle",  cast(^i32)&m.pogo_shape, cast(i32)Pogo_Shape.Circle)
		imgui.SameLine()
		imgui.RadioButtonIntPtr("Segment", cast(^i32)&m.pogo_shape, cast(i32)Pogo_Shape.Segment)

		imgui.Checkbox("Lock Camera", &m.lock_camera)
	}
}

plane_result_fcn :: proc "c" (shape_id: b2.ShapeId, plane_result: ^b2.PlaneResult, ctx: rawptr) -> bool {
	assert_contextless(plane_result.hit)

	m := (^Mover)(ctx)

	max_push      := max(f32)
	clip_velocity := true
	user_data     := (^Shape_User_Data)(b2.Shape_GetUserData(shape_id))

	if user_data != nil {
		max_push      = user_data.max_push
		clip_velocity = user_data.clip_velocity
	}

	if m.plane_count < len(m.planes) {
		// assert_contextless(b2.IsValidPlane(plane_result.plane))
		m.planes[m.plane_count] = {plane_result.plane, max_push, 0., clip_velocity}
		m.plane_count += 1
	}

	return true
}

kick :: proc "c" (shape_id: b2.ShapeId, ctx: rawptr) -> bool {
	m := (^Mover)(ctx)

	body_id := b2.Shape_GetBody(shape_id)
	type    := b2.Body_GetType(body_id)

	if type != .dynamicBody {
		return true
	}

	center    := b2.Body_GetWorldCenterOfMass(body_id)
	direction := b2.Normalize(center - m.transform.p)
	impulse   := Vec{2. * direction.x, 2.}
	b2.Body_ApplyLinearImpulseToCenter(body_id, impulse, true)

	return true
}

Key :: enum {
	None,
	Space,
	A,
	D,
	K,
}

Input :: bit_set[Key]

pixel_to_world :: proc(pxs: f32) -> f32 {
	world_per_pixel := linalg.min(nais.camera_view() / nais.window_size())
	return pxs * world_per_pixel
}

b2_draw:  b2.DebugDraw = {
		DrawPolygonFcn = proc "c" (vertices: [^]Vec, vertex_count: i32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			log.warn("todo: DrawPolygonFcn")
		},
		DrawSolidPolygonFcn = proc "c" (transform: b2.Transform, vertices: [^]Vec, vertex_count: i32, radius: f32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			log.warn("todo: DrawSolidPolygonFcn")
		},
		DrawCircleFcn = proc "c" (center: Vec, radius: f32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			nais.draw_circle_outline(center, radius, rgba(color), pixel_to_world(THICKNESS))
		},
		DrawSolidCircleFcn = proc "c" (transform: b2.Transform, radius: f32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			nais.draw_circle(transform.p, radius, rgba(color))
		},
		DrawSolidCapsuleFcn = proc "c" (p1, p2: Vec, radius: f32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			nais.draw_capsule(p1, p2, rgba(color), radius)
		},
		DrawSegmentFcn = proc "c" (p1, p2: Vec, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			nais.draw_segment(p1, p2, rgba(color), pixel_to_world(THICKNESS))
		},
		DrawTransformFcn = proc "c" (transform: b2.Transform, ctx: rawptr) {
			context = nais.ctx()
			log.warn("todo: DrawTransformFcn")
		},
		DrawPointFcn = proc "c" (p: Vec, size: f32, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			world := pixel_to_world(size)
			nais.draw_rectangle(p-(world*.5), world, rgba(color), 0)
		},
		DrawStringFcn = proc "c" (p: Vec, s: cstring, color: b2.HexColor, ctx: rawptr) {
			context = nais.ctx()
			log.warn("todo: DrawStringFcn")
		},

		drawShapes = true,
		// drawJoints = true,
		// drawJointExtras = true,
		// drawBounds = true,
		// drawMass = true,
		// drawBodyNames = true,
		// drawContacts = true,
		// drawContactNormals = true,
		// drawContactImpulses = true,
		// drawContactFeatures = true,
		// drawFrictionImpulses = true,
		// drawIslands = true,
	}

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	@static m:        Mover
	@static settings: Settings
	@static input:    Input

	nais.run("Dear Imgui", {1920, 1080}, {.VSync, .Low_Power, .Windowed_Fullscreen, .Save_Window_State}, proc(event: nais.Event) {
		nais_imgui.event(event)

		#partial switch e in event {
		case nais.Initialized:
			imgui.CHECKVERSION()
			imgui.CreateContext()

			io := imgui.GetIO()
			io.ConfigFlags += {.NavEnableKeyboard, .DockingEnable}
			imgui.StyleColorsDark()

			nais_imgui.init()

			world_def := b2.DefaultWorldDef()
			m.world_id = b2.CreateWorld(world_def)

			// TODO: call resize at startup too.
			sz := nais.window_size()
			g_camera.size = {sz.x/sz.y, 1}

			settings_init(&settings)
			mover_init(&m, &settings)

			nais.load_font_from_memory("default", #load("../_resources/NotoSans-500-100.ttf"))

		case nais.Resize:
			sz := nais.window_size()
			g_camera.size = {sz.x/sz.y, 1}

		case nais.Input:
			io := imgui.GetIO()
			if io.WantCaptureKeyboard {
				return
			}

			k: Key
			#partial switch e.key {
			case .Space: k = .Space
			case .A:     k = .A
			case .D:     k = .D
			case .K:     k = .K
			}

			if e.action == .Pressed {
				input += {k}
			}

			if e.action == .Released {
				input -= {k}
			}

		case nais.Frame:
			log.warn("frame")

			nais.background_set({1, 1, 1, 1})

			defer input -= {.Space}

			nais.camera_set(g_camera)

			pause := false
			if settings.pause {
				pause = settings.single_step != true
			}

			// time_step := settings.hertz > 0 ? 1 / settings.hertz : 0
			time_step := e.dt // TODO: ?
			if pause {
				time_step = 0
			}

			if time_step > 0 {
				point := Vec{
					ELEVATOR_BASE.x,
					ELEVATOR_AMPLITUDE * math.cos(1. * m.time + b2.PI) + ELEVATOR_BASE.y,
				}

				b2.Body_SetTargetTransform(m.elevator_id, {point, b2.Rot_identity}, time_step)
			}

			m.time += time_step

			{
				b2.World_Step(m.world_id, time_step, settings.sub_step_count)

				b2.World_Draw(m.world_id, &b2_draw)
			}

			if !pause {
				throttle := f32(0)

				if .A in input {
					throttle -= 1.
				}

				if .D in input {
					throttle += 1.
				}

				if .Space in input {
					if m.on_ground && m.jump_released {
						m.velocity.y = m.jump_speed
						m.on_ground = false
						m.jump_released = false
					}
				} else {
					m.jump_released = true
				}

				if .K in input {
					point := b2.TransformPoint(m.transform, {0., m.capsule.center1.y - 3. * m.capsule.radius})
					circle := b2.Circle{point, .5}
					proxy := b2.MakeProxy({circle.center}, circle.radius)
					filter := b2.QueryFilter{
						transmute(u64)Collision_Bits{.Mover},
						transmute(u64)Collision_Bits{.Debris},
					}
					_ = b2.World_OverlapShape(m.world_id, proxy, filter, kick, &m)
					nais.draw_circle_outline(circle.center, circle.radius, rgba(b2.HexColor.GoldenRod), pixel_to_world(THICKNESS))
				}

				solve_move(&m, time_step, throttle)
			}

			for plane in m.planes[:m.plane_count] {
				p1 := m.transform.p + (plane.plane.offset - m.capsule.radius) * plane.plane.normal
				p2 := p1 + .1 * plane.plane.normal
				nais.draw_rectangle(p1, pixel_to_world(10), rgba(b2.HexColor.Yellow), 0)
				nais.draw_segment(p1, p2, rgba(b2.HexColor.Yellow), pixel_to_world(THICKNESS))
			}

			p1 := b2.TransformPoint(m.transform, m.capsule.center1)
			p2 := b2.TransformPoint(m.transform, m.capsule.center2)

			color := m.on_ground ? b2.HexColor.Orange : b2.HexColor.Aquamarine
			nais.draw_capsule(p1, p2, rgba(color), m.capsule.radius)
			nais.draw_segment(m.transform.p, m.transform.p + m.velocity, rgba(b2.HexColor.Purple), pixel_to_world(THICKNESS))

			// p := m.transform.p
			// TODO:
			// DrawTextLine( "position %.2f %.2f", p.x, p.y );
			// DrawTextLine( "velocity %.2f %.2f", m_velocity.x, m_velocity.y );
			// DrawTextLine( "iterations %d", m_totalIterations );

			if m.lock_camera {
				g_camera.target = m.transform.p
			}

			imgui.NewFrame()
			defer imgui.Render()

			update_gui(&m)
		}
	})
}

parse_path :: proc(path: string, offset: Vec, points: []Vec, scale: f32) -> (point_count: int) {
	path := path
	current_point: Vec
	command: byte

	is_digit :: proc(ch: byte) -> bool { return ch >= '0' && ch <= '9' }

	path_loop: for len(path) > 0 {
		if !is_digit(path[0]) && path[0] != '-' {
			command = path[0]
			switch command {
			case 'M', 'L', 'H', 'V', 'm', 'l', 'h', 'v':
				path = path[2:] // Skip the command character and space.
			case 'z':
				break path_loop
			}
		}

		assert(is_digit(path[0]) || path[0] == '-')

		x, y: f32
		switch command {
		case 'M', 'L':
			n: int
			current_point.x, _ = strconv.parse_f32(path, &n)	
			assert(n > 0)
			path = path[n:]

			assert(path[0] == ',')
			path = path[1:]

			current_point.y, _ = strconv.parse_f32(path, &n)
			assert(n > 0)
			path = path[n:]

		case 'H':
			n: int
			current_point.x, _ = strconv.parse_f32(path, &n)
			assert(n > 0)
			path = path[n:]

		case 'V':
			n: int
			current_point.y, _ = strconv.parse_f32(path, &n)
			assert(n > 0)
			path = path[n:]

		case 'm', 'l':
			n: int
			x_inc, _ := strconv.parse_f32(path, &n)	
			current_point.x += x_inc
			assert(n > 0)
			path = path[n:]

			assert(path[0] == ',')
			path = path[1:]

			y_inc, _ := strconv.parse_f32(path, &n)
			current_point.y += y_inc
			assert(n > 0)
			path = path[n:]

		case 'h':
			n: int
			x_inc, _ := strconv.parse_f32(path, &n)
			current_point.x += x_inc
			assert(n > 0)
			path = path[n:]

		case 'v':
			n: int
			y_inc, _ := strconv.parse_f32(path, &n)
			current_point.y += y_inc
			assert(n > 0)
			path = path[n:]
		case:
			panic("unknown command")
		}

		points[point_count] = { scale * (current_point.x + offset.x), -scale * (current_point.y + offset.y) }
		point_count += 1
		if point_count == len(points) {
			break
		}

		path = strings.trim_left_space(path)
	}

	return
}
