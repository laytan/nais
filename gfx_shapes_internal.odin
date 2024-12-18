#+private
package nais

import sa     "core:container/small_array"
import        "core:log"
import        "core:math/linalg"
import        "core:math"

import       "vendor:wgpu"

MAX_VERTICES :: 56_000

@(private="file")
g := struct{
	vertices:  sa.Small_Array(MAX_VERTICES, [2]f32),
	colors:    sa.Small_Array(MAX_VERTICES, u32),
	draws:     sa.Small_Array(MAX_VERTICES/3, u32),

	constant_buffer:  wgpu.Buffer,
	vertex_buffer:    wgpu.Buffer,
	color_buffer:     wgpu.Buffer,
	bindgroup:        wgpu.BindGroup,
	bindgroup_layout: wgpu.BindGroupLayout,
	module:           wgpu.ShaderModule,
	pipeline_layout:  wgpu.PipelineLayout,
	pipeline:         wgpu.RenderPipeline,
}{}

@(private="file")
Constants :: struct #packed {
	transformation: matrix[4, 4]f32,
}
#assert(size_of(Constants) % 16 == 0)

_gfx_init_shapes :: proc() {
	device := g_window.gfx.config.device

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.constant_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "Constants",
		usage = { .Uniform, .CopyDst },
		size  = size_of(Constants),
	})

	_gfx_shapes_write_consts()


	g.vertex_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "Vertices",
		usage = { .CopyDst, .Vertex },
		size  = size_of([2]f32) * MAX_VERTICES,
	})

	g.color_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "Colors",
		usage = { .CopyDst, .Vertex },
		size  = size_of(u32) * MAX_VERTICES,
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.bindgroup_layout = wgpu.DeviceCreateBindGroupLayout(device, &{
		entryCount = 1,
		entries    = raw_data([]wgpu.BindGroupLayoutEntry{
			{
				binding    = 0,
				visibility = { .Vertex },
				buffer     = {
					type           = .Uniform,
					minBindingSize = size_of(Constants),
				},
			},
		}),
	})

	g.bindgroup = wgpu.DeviceCreateBindGroup(device, &{
		layout     = g.bindgroup_layout,
		entryCount = 1,
		entries    = raw_data([]wgpu.BindGroupEntry{
			{
				binding = 0,
				buffer  = g.constant_buffer,
				size    = size_of(Constants),
			},
		}),
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.module = wgpu.DeviceCreateShaderModule(device, &{
		nextInChain = &wgpu.ShaderModuleWGSLDescriptor{
			sType = .ShaderModuleWGSLDescriptor,
			code  = #load("gfx_shapes.wgsl"),
		},
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.pipeline_layout = wgpu.DeviceCreatePipelineLayout(device, &{
		bindGroupLayoutCount = 1,
		bindGroupLayouts     = &g.bindgroup_layout,
	})
	g.pipeline = wgpu.DeviceCreateRenderPipeline(device, &{
		layout = g.pipeline_layout,
		vertex = {
			module     = g.module,
			entryPoint = "vs",
			bufferCount = 2,
			buffers = raw_data([]wgpu.VertexBufferLayout{
				{
					arrayStride = size_of([2]f32),
					stepMode = .Vertex,
					attributeCount = 1,
					attributes = raw_data([]wgpu.VertexAttribute{
						{
							format         = .Float32x2,
							shaderLocation = 0,
						},
					}),
				},
				{
					arrayStride = size_of(u32),
					stepMode = .Vertex,
					attributeCount = 1,
					attributes = raw_data([]wgpu.VertexAttribute{
						{
							format         = .Uint32,
							shaderLocation = 1,
						},
					}),
				},
			}),
		},
		fragment = &{
			module      = g.module,
			entryPoint  = "ps",
			targetCount = 1,
			targets     = &wgpu.ColorTargetState{
				format = .BGRA8Unorm,
				blend = &{
					color = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
					alpha = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
				},
				writeMask = wgpu.ColorWriteMaskFlags_All,
			},
		},
		primitive = {
			topology = .TriangleList,
			cullMode = .Back,

		},
		multisample = {
			count = 1,
			mask  = 0xFFFFFFFF,
		},
	})

	append(&g_window.gfx.renderers, _shapes_renderer)
}

_gfx_shapes_write_consts :: proc() {
	queue  := g_window.gfx.queue

	window := window_size()

	transformation := linalg.matrix_ortho3d(0, window.x, window.y, 0, -1, 1)// * linalg.matrix4_scale_f32({1/dpi.x, 1/dpi.y, 1})

	constants := Constants{ 
		transformation = transformation,
	}

	wgpu.QueueWriteBuffer(queue, g.constant_buffer, 0, &constants, size_of(constants))
}

_shapes_renderer :: proc(ev: Renderer_Event) {
	switch e in ev {
	case Renderer_Resize:
		_gfx_shapes_write_consts()

	case Renderer_Flush:
		if sa.len(g.vertices) == 0 {
			return
		}

		log.debugf("drawing %v vertices", sa.len(g.vertices))

		queue  := g_window.gfx.queue

		wgpu.QueueWriteBuffer(queue, g.vertex_buffer, 0, &g.vertices.data, uint(size_of([2]f32)*sa.len(g.vertices)))
		wgpu.QueueWriteBuffer(queue, g.color_buffer, 0, &g.colors.data, uint(size_of(u32)*sa.len(g.colors)))

		wgpu.RenderPassEncoderSetPipeline(e.pass, g.pipeline)
		wgpu.RenderPassEncoderSetBindGroup(e.pass, 0, g.bindgroup)

		assert(sa.len(g.colors) == sa.len(g.vertices))

		wgpu.RenderPassEncoderSetVertexBuffer(e.pass, 0, g.vertex_buffer, 0, u64(size_of([2]f32)*sa.len(g.vertices)))
		wgpu.RenderPassEncoderSetVertexBuffer(e.pass, 1, g.color_buffer, 0, u64(size_of(u32)*sa.len(g.colors)))

		// TODO: this can't be how to do it.
		tally: u32
		for draw in sa.slice(&g.draws) {
			wgpu.RenderPassEncoderDraw(e.pass, u32(draw), 1, tally, 0)
			tally += u32(draw)
		}

		sa.clear(&g.vertices)
		sa.clear(&g.colors)
		sa.clear(&g.draws)

	case Renderer_Frame:
		assert(sa.len(g.vertices) == 0)
		assert(sa.len(g.draws) == 0)
		assert(sa.len(g.colors) == 0)
	}
}

_draw_triangle :: proc(points: [3][2]f32, color: u32) {
	_gfx_swap_renderer(_shapes_renderer, true)

	points := points
	sa.append_elems(&g.vertices, ..points[:])
	sa.append_elems(&g.colors, ..[]u32{color, color, color})
	sa.append(&g.draws, 3)
}

_draw_triangle_strip :: proc(points: [][2]f32, color: u32) {
	if len(points) < 3 {
		return
	}

	_gfx_swap_renderer(_shapes_renderer, true)

	draws := u32(0)
	for i in 2..<len(points) {
		if (i % 2) == 0 {
			sa.append_elems(
				&g.vertices,
				points[i],
				points[i-2],
				points[i-1],
			)
		} else {
			sa.append_elems(
				&g.vertices,
				points[i],
				points[i-1],
				points[i-2],
			)
		}
		draws += 3
	}

	for _ in 0..<draws {
		sa.append(&g.colors, color)
	}

	sa.append(&g.draws, draws)
}

_draw_line :: proc(start, end: [2]f32, thick: f32, color: u32) {
	delta  := end - start
	length := linalg.length(delta)

	if length > 0 && thick > 0 {
		scale := thick/(2*length)
		radius := [2]f32{-scale*delta.y, scale*delta.x}

		_draw_triangle_strip({
			{start.x - radius.x, start.y - radius.y},
			{start.x + radius.x, start.y + radius.y},
			{end.x - radius.x, end.y - radius.y},
			{end.x + radius.x, end.y + radius.y},
		}, color)
	}
}

SMOOTH_CIRCLE_ERROR_RATE :: 0.5

Rect :: struct {
	x, y, w, h: f32,
}

// rectangle rounded, ring
_draw_rectangle_rounded :: proc(rec: Rect, roundness: f32, segments: int, color: u32) {
	if roundness <= 0 || rec.w < 1 || rec.h < 1 {
		// TODO: color
		draw_rectangle({rec.x, rec.y}, {rec.w, rec.h}, color)
		return
	}

	roundness := roundness
	roundness = min(roundness, 1.)

	radius := rec.w > rec.h ? rec.h * roundness / 2 : rec.w * roundness / 2
	if radius <= 0 {
		return
	}

	_gfx_swap_renderer(_shapes_renderer, true)

	segments := segments
	if segments < 4 {
		th := math.acos(2*math.pow(1 - SMOOTH_CIRCLE_ERROR_RATE/radius, 2) - 1)
		segments = int(math.ceil(2*math.PI/th)/4.)
		if segments <= 0 {
			segments = 4
		}
	}

	step_length := 90./f32(segments)

	points := [12][2]f32{
		{rec.x + radius, rec.y}, {rec.x + rec.w - radius, rec.y}, {rec.x + rec.w, rec.y + radius},
		{rec.x + rec.w, rec.y + rec.h - radius}, {rec.x + rec.w - radius, rec.y + rec.h},
		{rec.x + radius, rec.y + rec.h}, {rec.x, rec.y + rec.h - radius}, {rec.x, rec.y + radius},
		{rec.x + radius, rec.y + radius}, {rec.x + rec.w - radius, rec.y + radius},
		{rec.x + rec.w - radius, rec.y + rec.h - radius}, {rec.x + radius, rec.y + rec.h - radius},
	}
	centers := [4][2]f32{ points[8], points[9], points[10], points[11] }
	angles := [4]f32{ 180., 270., 0., 90. }

	draws: int

	#unroll for k in 0..<4 {
		angle := angles[k]
		center := centers[k]
		for _ in 0..<segments {
			sa.append_elems(
				&g.vertices,
				center,
				[2]f32{center.x + math.cos(math.to_radians(angle + step_length))*radius, center.y + math.sin(math.to_radians(angle + step_length))*radius},
				[2]f32{center.x + math.cos(math.to_radians(angle))*radius, center.y + math.sin(math.to_radians(angle))*radius},
			)
			angle += step_length
			draws += 3
		}
	}

	sa.append_elems(
		&g.vertices,

		points[0],
		points[8],
		points[9],
		points[1],
		points[0],
		points[9],

		points[9],
		points[10],
		points[3],
		points[2],
		points[9],
		points[3],

		points[11],
		points[5],
		points[4],
		points[10],
		points[11],
		points[4],

		points[7],
		points[6],
		points[11],
		points[8],
		points[7],
		points[11],

		points[8],
		points[11],
		points[10],
		points[9],
		points[8],
		points[10],
	)

	draws += 5 * 6

	for _ in 0..<draws {
		sa.append(&g.colors, color)
	}

	sa.append(&g.draws, u32(draws))
}

_draw_circle_sector :: proc(center: [2]f32, radius, start_angle, end_angle: f32, segments: int, color: u32) {
	_gfx_swap_renderer(_shapes_renderer, true)

	radius := radius
	radius = max(radius, .1)

	end_angle, start_angle := end_angle, start_angle
	if end_angle < start_angle {
		end_angle, start_angle = start_angle, end_angle
	}

	min_segments := int(math.ceil(end_angle - start_angle)/90)

	segments := segments
	if segments < min_segments {
		th := math.acos(2*math.pow(1 - SMOOTH_CIRCLE_ERROR_RATE / radius, 2) - 1)
		segments = int((end_angle - start_angle)*math.ceil(2*math.PI/th)/360)
		if segments <= 0 {
			segments = min_segments
		}
	}

	step_length := (end_angle - start_angle) / f32(segments)
	angle := start_angle

	for _ in 0..<segments {
		sa.append_elems(
			&g.vertices,

			center,
			[2]f32{center.x + math.cos(math.to_radians(angle + step_length))*radius, center.y + math.sin(math.to_radians(angle + step_length))*radius},
			[2]f32{center.x + math.cos(math.to_radians(angle))*radius, center.y + math.sin(math.to_radians(angle))*radius},
		)

		angle += step_length
	}

	draws := u32(segments * 3)
	for _ in 0..<draws {
		sa.append(&g.colors, color)
	}

	sa.append_elem(&g.draws, draws)
}

_draw_ring :: proc(center: [2]f32, inner_radius, outer_radius, start_angle, end_angle: f32, segments: int, color: u32) {
	if start_angle == end_angle {
		return
	}

	outer_radius, inner_radius := outer_radius, inner_radius
	if outer_radius < inner_radius {
		outer_radius, inner_radius = inner_radius, outer_radius
	}

	if inner_radius <= 0 {
		_draw_circle_sector(center, outer_radius, start_angle, end_angle, segments, color)
		return
	}

	_gfx_swap_renderer(_shapes_renderer, true)

	min_segments := int(math.ceil((end_angle - start_angle) / 90.))

	segments := segments
	if segments < min_segments {
		th := math.acos(2*math.pow(1 - SMOOTH_CIRCLE_ERROR_RATE / outer_radius, 2) - 1)
		segments = int((end_angle - start_angle) * math.ceil(2*math.PI/th)/360)
		if segments <= 0 {
			segments = min_segments
		}
	}

	step_length := (end_angle - start_angle) / f32(segments)
	angle := start_angle

	for _ in 0..<segments {
		sa.append_elems(
			&g.vertices,

			[2]f32{center.x + math.cos(math.to_radians(angle))*inner_radius, center.y + math.sin(math.to_radians(angle))*inner_radius},
			[2]f32{center.x + math.cos(math.to_radians(angle + step_length))*inner_radius, center.y + math.sin(math.to_radians(angle + step_length))*inner_radius},
			[2]f32{center.x + math.cos(math.to_radians(angle))*outer_radius, center.y + math.sin(math.to_radians(angle))*outer_radius},

			[2]f32{center.x + math.cos(math.to_radians(angle + step_length))*inner_radius, center.y + math.sin(math.to_radians(angle + step_length))*inner_radius},
			[2]f32{center.x + math.cos(math.to_radians(angle + step_length))*outer_radius, center.y + math.sin(math.to_radians(angle + step_length))*outer_radius},
			[2]f32{center.x + math.cos(math.to_radians(angle))*outer_radius, center.y + math.sin(math.to_radians(angle))*outer_radius},
		)

		angle += step_length
	}

	draws := u32(segments * 6)
	for _ in 0..<draws {
		sa.append(&g.colors, color)
	}

	sa.append_elem(&g.draws, draws)
}
