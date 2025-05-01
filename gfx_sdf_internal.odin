#+private
package nais

import sa "core:container/small_array"
import    "core:log"
import    "core:math/linalg"

import    "vendor:wgpu"

Constants :: struct #packed {
	mvp: matrix[4, 4]f32,
}
#assert(size_of(Constants) % 16 == 0)

Shape :: struct {
	position:     [2]f32,
	size:         [2]f32,
	rounding:     [4]f32,
	color:        [4]f32,
	border_width: [4]f32,
}
#assert(size_of(Shape) % 16 == 0)

Shape_Type :: enum u32 {
	Circle,
	Rectangle,
	Rectangle_Outline,
	Capsule,
	Circle_Outline,
	Segment,
}

MAX_SHAPES :: 1024

BORDER_WIDTH_CIRCLE         :: [4]f32{-1, 0, 0, 0}
BORDER_WIDTH_RECTANGLE      :: [4]f32{-2, 0, 0, 0}
BORDER_WIDTH_CAPSULE        :: [4]f32{-3, 0, 0, 0}
BORDER_WIDTH_CIRCLE_OUTLINE :: [4]f32{-4, 0, 0, 0}
BORDER_WIDTH_SEGMENT        :: [4]f32{-5, 0, 0, 0}

_draw_circle_sdf :: proc(position: [2]f32, radius: f32, color: [4]f32) {
	if radius == 0 || color.a == 0 {
		return
	}

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = position - radius,
		size         = radius * 2,
		color        = color,
		border_width = BORDER_WIDTH_CIRCLE,
	})
}

_draw_circle_outline_sdf :: proc(position: [2]f32, radius: f32, color: [4]f32, thickness: f32) {
	if radius == 0 || color.a == 0 || thickness == 0 {
		return
	}

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = position - radius,
		size         = radius * 2,
		color        = color,
		border_width = BORDER_WIDTH_CIRCLE_OUTLINE,
		rounding     = thickness,
	})
}

_draw_rectangle_sdf :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32, angle: f32) {
	if size == 0 || color.a == 0 {
		return
	}

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = position,
		size         = size,
		color        = color,
		rounding     = rounding,
		border_width = {BORDER_WIDTH_RECTANGLE.x, angle, 0, 0},
	})
}

_draw_rectangle_outline_sdf :: proc(position: [2]f32, size: [2]f32, color: [4]f32, rounding: [4]f32, thickness: [4]f32) {
	if size == 0 || color.a == 0 || thickness == 0 {
		return
	}

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = position,
		size         = size,
		color        = color,
		rounding     = rounding,
		border_width = thickness,
	})
}

_draw_capsule_sdf :: proc(p1, p2: [2]f32, color: [4]f32, radius: f32) {
	// TODO: validate

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = linalg.min(p1, p2) - radius,
		size         = linalg.abs(p2 - p1) + radius * 2,
		color        = color,
		rounding     = {p1.x, p1.y, p2.x, p2.y},
		border_width = {BORDER_WIDTH_CAPSULE.x, radius, 0, 0},
	})
}

_draw_segment_sdf :: proc(p1, p2: [2]f32, color: [4]f32, thickness: f32) {
	// TODO: validate

	_gfx_swap_renderer(_sdf_renderer, true)

	sa.append(&g.shapes, Shape{
		position     = linalg.min(p1, p2) - thickness,
		size         = linalg.abs(p2 - p1) + thickness * 2,
		color        = color,
		rounding     = {p1.x, p1.y, p2.x, p2.y},
		border_width = {BORDER_WIDTH_SEGMENT.x, thickness, 0, 0},
	})
}

@(private="file")
g := struct{
	shapes:           sa.Small_Array(MAX_SHAPES, Shape),
	constant_buffer:  wgpu.Buffer,
	shapes_buffer:    wgpu.Buffer,
	bindgroup:        wgpu.BindGroup,
	bindgroup_layout: wgpu.BindGroupLayout,
	module:           wgpu.ShaderModule,
	pipeline_layout:  wgpu.PipelineLayout,
	pipeline:         wgpu.RenderPipeline,
}{}

_gfx_init_sdf :: proc() {
	device := g_window.gfx.config.device

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.constant_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "SDF - Constants",
		usage = { .Uniform, .CopyDst },
		size  = size_of(Constants),
	})

	_gfx_sdf_write_consts()

	g.shapes_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "SDF - Shapes",
		usage = { .CopyDst, .Storage },
		size  = size_of(Shape) * MAX_SHAPES,
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.bindgroup_layout = wgpu.DeviceCreateBindGroupLayout(device, &{
		entryCount = 2,
		entries    = raw_data([]wgpu.BindGroupLayoutEntry{
			{
				binding    = 0,
				visibility = { .Vertex },
				buffer     = {
					type           = .Uniform,
					minBindingSize = size_of(Constants),
				},
			},
			{
				binding    = 1,
				visibility = { .Vertex },
				buffer     = {
					type           = .ReadOnlyStorage,
					minBindingSize = size_of(Shape) * MAX_SHAPES,
				},
			},
		}),
	})

	g.bindgroup = wgpu.DeviceCreateBindGroup(device, &{
		layout     = g.bindgroup_layout,
		entryCount = 2,
		entries    = raw_data([]wgpu.BindGroupEntry{
			{
				binding = 0,
				buffer  = g.constant_buffer,
				size    = size_of(Constants),
			},
			{
				binding = 1,
				buffer  = g.shapes_buffer,
				size    = size_of(Shape) * MAX_SHAPES,
			},
		}),
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.module = wgpu.DeviceCreateShaderModule(device, &{
		label = "SDF - Shader Module",
		nextInChain = &wgpu.ShaderSourceWGSL{
			sType = .ShaderSourceWGSL,
			code  = #load("gfx_sdf.wgsl"),
		},
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.pipeline_layout = wgpu.DeviceCreatePipelineLayout(device, &{
		bindGroupLayoutCount = 1,
		bindGroupLayouts     = &g.bindgroup_layout,
	})
	g.pipeline = wgpu.DeviceCreateRenderPipeline(device, &{
		label = "SDF - Pipeline",
		layout = g.pipeline_layout,
		vertex = {
			module     = g.module,
			entryPoint = "vs",
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
			topology = .TriangleStrip,
			// cullMode = .Back,

		},
		multisample = {
			count = 1,
			mask  = 0xFFFFFFFF,
		},
	})

	append(&g_window.gfx.renderers, _sdf_renderer)
}

_gfx_sdf_write_consts :: proc() {
	queue  := g_window.gfx.queue

	constants := Constants{ 
		mvp = _camera_matrix(window_size()),
	}

	wgpu.QueueWriteBuffer(queue, g.constant_buffer, 0, &constants, size_of(constants))
}

_sdf_renderer :: proc(ev: Renderer_Event) {
	switch e in ev {
	case Renderer_Resize:
		_gfx_sdf_write_consts()

	case Renderer_Flush:
		if sa.len(g.shapes) == 0 {
			return
		}

		log.debugf("drawing %v shapes", sa.len(g.shapes))

		queue  := g_window.gfx.queue

		wgpu.QueueWriteBuffer(queue, g.shapes_buffer, 0, &g.shapes.data, uint(size_of(Shape)*sa.len(g.shapes)))

		wgpu.RenderPassEncoderSetPipeline(e.pass, g.pipeline)
		wgpu.RenderPassEncoderSetBindGroup(e.pass, 0, g.bindgroup)
		wgpu.RenderPassEncoderDraw(e.pass, 4, u32(sa.len(g.shapes)), 0, 0)

		sa.clear(&g.shapes)

	case Renderer_Frame:
		assert(sa.len(g.shapes) == 0)
	}
}
