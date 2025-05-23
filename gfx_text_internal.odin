#+private
package nais

import    "core:log"
import    "core:strings"
import sa "core:container/small_array"

import fs "vendor:fontstash"
import    "vendor:wgpu"

DEFAULT_FONT_ATLAS_SIZE :: 512
MAX_FONT_INSTANCES      :: 8192

@(private="file")
g := struct{
	fs: fs.FontContext,

	font_instances:     sa.Small_Array(MAX_FONT_INSTANCES, Font_Instance),
	font_instances_buf: wgpu.Buffer,
	font_index_buf:     wgpu.Buffer,

	module: wgpu.ShaderModule,

	atlas_texture:      wgpu.Texture,
	atlas_texture_view: wgpu.TextureView,

	pipeline_layout: wgpu.PipelineLayout,
	pipeline:        wgpu.RenderPipeline,

	const_buffer: wgpu.Buffer,

	sampler: wgpu.Sampler,

	bind_group_layout: wgpu.BindGroupLayout,
	bind_group:        wgpu.BindGroup,
}{}

Font_Instance :: struct {
	pos_min: [2]f32,
	pos_max: [2]f32,
	uv_min:  [2]f32,
	uv_max:  [2]f32,
	color:   [4]u8,
}

_load_font_from_memory :: proc(name: string, data: []byte) -> Font {
	return Font(fs.AddFontMem(&g.fs, name, data, freeLoadedData=false))
}

_gfx_init_text :: proc() {
	device := g_window.gfx.config.device

	fs.Init(&g.fs, DEFAULT_FONT_ATLAS_SIZE, DEFAULT_FONT_ATLAS_SIZE, .TOPLEFT)

	g.font_instances_buf = wgpu.DeviceCreateBuffer(device, &{
		label = "[nais][text]: font instance",
		usage = { .Vertex, .CopyDst },
		size = size_of(g.font_instances.data),
	})

	g.font_index_buf = wgpu.DeviceCreateBufferWithData(device, &{
		label = "[nais][text]: font index",
		usage = { .Index, .Uniform },
	}, []u32{0, 1, 2, 1, 2, 3})

	g.const_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "[nais][text]: constants",
		usage = { .Uniform, .CopyDst },
		size  = size_of(matrix[4, 4]f32),
	})

	g.sampler = wgpu.DeviceCreateSampler(device, &{
		label         = "[nais][text]: sampler",
		addressModeU  = .ClampToEdge,
		addressModeV  = .ClampToEdge,
		addressModeW  = .ClampToEdge,
		magFilter     = .Linear,
		minFilter     = .Linear,
		mipmapFilter  = .Linear,
		lodMinClamp   = 0,
		lodMaxClamp   = 32,
		compare       = .Undefined,
		maxAnisotropy = 1,
	})

	g.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(device, &{
		label = "[nais][text]: bind group layout",
		entryCount = 3,
		entries = raw_data([]wgpu.BindGroupLayoutEntry{
			{
				binding = 0,
				visibility = { .Fragment },
				sampler = {
					type = .Filtering,
				},
			},
			{
				binding = 1,
				visibility = { .Fragment },
				texture = {
					sampleType = .Float,
					viewDimension = ._2D,
					multisampled = false,
				},
			},
			{
				binding = 2,
				visibility = { .Vertex },
				buffer = {
					type = .Uniform,
					minBindingSize = size_of(matrix[4, 4]f32),
				},
			},
		}),
	})

	_gfx_text_create_atlas()

	g.module = wgpu.DeviceCreateShaderModule(device, &{
		label = "[nais][text]: shader",
		nextInChain = &wgpu.ShaderSourceWGSL{
			sType = .ShaderSourceWGSL,
			code  = #load("gfx_text.wgsl"),
		},
	})

	g.pipeline_layout = wgpu.DeviceCreatePipelineLayout(device, &{
		label = "[nais][text]: pipeline layout",
		bindGroupLayoutCount = 1,
		bindGroupLayouts = &g.bind_group_layout,
	})
	g.pipeline = wgpu.DeviceCreateRenderPipeline(device, &{
		label = "[nais][text]: pipeline",
		layout = g.pipeline_layout,
		vertex = {
			module = g.module,
			entryPoint = "vs_main",
			bufferCount = 1,
			buffers = raw_data([]wgpu.VertexBufferLayout{
				{
					arrayStride = size_of(Font_Instance),
					stepMode    = .Instance,
					attributeCount = 5,
					attributes = raw_data([]wgpu.VertexAttribute{
						{
							format         = .Float32x2,
							shaderLocation = 0,
						},
						{
							format         = .Float32x2,
							shaderLocation = 1,
							offset         = 8,
						},
						{
							format         = .Float32x2,
							shaderLocation = 2,
							offset         = 16,
						},
						{
							format         = .Float32x2,
							shaderLocation = 3,
							offset         = 24,
						},
						{
							format         = .Uint32,
							shaderLocation = 4,
							offset         = 32,
						},
					}),
				},
			}),
		},
		fragment = &{
			module = g.module,
			entryPoint = "fs_main",
			targetCount = 1,
			targets = &wgpu.ColorTargetState{
				format = .BGRA8Unorm,
				blend = &{
					alpha = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
					color = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
				},
				writeMask = wgpu.ColorWriteMaskFlags_All,
			},
		},
		primitive = {
			topology  = .TriangleList,
		},
		multisample = {
			count = 1,
			mask = 0xFFFFFFFF,
		},
	})

	_gfx_text_write_consts()

	append(&g_window.gfx.renderers, _text_renderer)
}

_gfx_text_write_consts :: proc() {
	queue  := g_window.gfx.queue

	proj := _camera_matrix(frame_buffer_size())

	wgpu.QueueWriteBuffer(queue, g.const_buffer, 0, &proj, size_of(proj))
}

_gfx_text_create_atlas :: proc() {
	device := g_window.gfx.config.device

	g.atlas_texture = wgpu.DeviceCreateTexture(device, &{
		label = "[nais][text]: atlas texture",
		usage = { .TextureBinding, .CopyDst },
		dimension = ._2D,
		size = { u32(g.fs.width), u32(g.fs.height), 1 },
		format = .R8Unorm,
		mipLevelCount = 1,
		sampleCount = 1,
	})
	g.atlas_texture_view = wgpu.TextureCreateView(g.atlas_texture)
	// NOTE: unimplemented in wgpu-native.
	when ODIN_OS == .JS {
		wgpu.TextureViewSetLabel(g.atlas_texture_view, "[nais][text]: atlas texture view")
	}

	g.bind_group = wgpu.DeviceCreateBindGroup(device, &{
		label = "[nais][text]: bind group",
		layout = g.bind_group_layout,
		entryCount = 3,
		entries = raw_data([]wgpu.BindGroupEntry{
			{
				binding = 0,
				sampler = g.sampler,
			},
			{
				binding = 1,
				textureView = g.atlas_texture_view,
			},
			{
				binding = 2,
				buffer = g.const_buffer,
				size = size_of(matrix[4, 4]f32),
			},
		}),
	})

	_gfx_text_write_atlas()
}

_gfx_text_write_atlas :: proc() {
	queue  := g_window.gfx.queue

	wgpu.QueueWriteTexture(
		queue,
		&{ texture = g.atlas_texture },
		raw_data(g.fs.textureData),
		uint(g.fs.width * g.fs.height),
		&{
			bytesPerRow  = u32(g.fs.width),
			rowsPerImage = u32(g.fs.height),
		},
		&{ u32(g.fs.width), u32(g.fs.height), 1 },
	)
}

_text_renderer :: proc(ev: Renderer_Event) {
	switch e in ev {
	case Renderer_Resize:
		_gfx_text_write_consts()

	case Renderer_Flush:
		queue := g_window.gfx.queue

		if (
			wgpu.TextureGetHeight(g.atlas_texture) != u32(g.fs.height) ||
			wgpu.TextureGetWidth(g.atlas_texture)  != u32(g.fs.width)
		) {
			log.info("text atlas has grown to", g.fs.width, g.fs.height)
			wgpu.TextureViewRelease(g.atlas_texture_view)
			wgpu.TextureRelease(g.atlas_texture)
			wgpu.BindGroupRelease(g.bind_group)
			_gfx_text_create_atlas()
			fs.__dirtyRectReset(&g.fs)
		} else {
			dirty_texture := g.fs.dirtyRect[0] < g.fs.dirtyRect[2] && g.fs.dirtyRect[1] < g.fs.dirtyRect[3]
			if dirty_texture {

				// NOTE: could technically only update the part of the texture that changed,
				// seems non-trivial though.

				log.info("text atlas is dirty, updating")
				_gfx_text_write_atlas()
				fs.__dirtyRectReset(&g.fs)
			}
		}

		if g.font_instances.len > 0 {
			log.debugf("drawing %v font instances", g.font_instances.len)

			wgpu.QueueWriteBuffer(
				queue,
				g.font_instances_buf,
				0,
				&g.font_instances.data,
				uint(g.font_instances.len) * size_of(Font_Instance),
			)

			wgpu.RenderPassEncoderSetPipeline(e.pass, g.pipeline)
			wgpu.RenderPassEncoderSetBindGroup(e.pass, 0, g.bind_group)

			wgpu.RenderPassEncoderSetVertexBuffer(e.pass, 0, g.font_instances_buf, 0, u64(g.font_instances.len) * size_of(Font_Instance))
			wgpu.RenderPassEncoderSetIndexBuffer(e.pass, g.font_index_buf, .Uint32, 0, wgpu.BufferGetSize(g.font_index_buf))

			wgpu.RenderPassEncoderDrawIndexed(e.pass, indexCount=6, instanceCount=u32(g.font_instances.len), firstIndex=0, baseVertex=0, firstInstance=0)

			sa.clear(&g.font_instances)
		}

	case Renderer_Frame:
		assert(sa.len(g.font_instances) == 0)
	}
}

// TODO: only width, make user call line height for height
_measure_text :: proc(
    text: string,
    size: f32 = 36,
    spacing: f32 = 0,
    blur: f32 = 0,
    font: Font = 0,
) -> (w, h: f32) {
	if len(text) == 0 {
		return
	}

	dpi := dpi().x

	g.fs.state_count = 1
	state := fs.__getState(&g.fs)
	state^ = {
		size    = size * dpi,
		blur    = blur,
		spacing = spacing,
		font    = int(font),
		ah      = .LEFT,
		av      = .BASELINE,
	}

	_, _, h = fs.VerticalMetrics(&g.fs)
	h /= dpi

	w = fs.TextBounds(&g.fs, text, 0, 0) / 2
	return
}

_measure_text_iter_init :: proc(
	iter: ^Measure_Text_Iter,
    text: string,
    size: f32 = 36,
    spacing: f32 = 0,
    blur: f32 = 0,
    font: Font = 0,
) {
	iter.scale = dpi().x

	g.fs.state_count = 1
	state := fs.__getState(&g.fs)
	state^ = {
		size    = size * iter.scale,
		blur    = blur,
		spacing = spacing,
		font    = int(font),
		ah      = .LEFT,
		av      = .BASELINE,
	}

	iter.iter = fs.TextIterInit(&g.fs, 0, 0, text)
}

_measure_text_iter :: proc(iter: ^Measure_Text_Iter) -> (w: f32, i: int, ok: bool) {
	quad: fs.Quad
	fs.TextIterNext(&g.fs, &iter.iter, &quad) or_return

	i = iter.i
	iter.i += 1
	w  = iter.iter.nextx / iter.scale
	ok = true
	return
}

_draw_text :: proc(
    text: string,
    pos: [2]f32,
    size: f32,
    color: [4]u8,
    blur: f32,
    spacing: f32,
    font: Font,
    align_h: Text_Align_Horizontal,
    align_v: Text_Align_Vertical,
    // x_inc: ^f32,
 //    y_inc: ^f32,
	// flush: bool,
) {
	if len(text) == 0 {
		return
	}

	if color.a == 0 {
		return
	}

	// assert(!strings.contains_any(text, "\t\r\n"), "unsupported character in text")

	_gfx_swap_renderer(_text_renderer, true)

	dpi := dpi()
	assert(dpi.x == dpi.y, "unimplemented support for weird dpi")

	g.fs.state_count = 1
	state := fs.__getState(&g.fs)
	state^ = {
		size    = size * dpi.x,
		blur    = blur,
		spacing = spacing,
		font    = int(font),
		ah      = fs.AlignHorizontal(align_h),
		av      = fs.AlignVertical(align_v),
	}

	// _, _, lh := fs.VerticalMetrics(&g.fs)

	pos := pos
	pos *= dpi.x

	// iter_text := text
	// for line in strings.split_lines_iterator(&iter_text) {
		for iter := fs.TextIterInit(&g.fs, pos.x, pos.y, text); true; {
			quad: fs.Quad
			fs.TextIterNext(&g.fs, &iter, &quad) or_break

			added := sa.append(
				&g.font_instances,
				Font_Instance {
					pos_min = {quad.x0, quad.y0},
					pos_max = {quad.x1, quad.y1},
					uv_min  = {quad.s0, quad.t0},
					uv_max  = {quad.s1, quad.t1},
					color   = color,
				},
			)
			if !added {
				log.panicf("maximum font instances of %v exceeded", len(g.font_instances.data))
			}
		}

		// pos.y += lh
	// }

	// if y_inc != nil {
	// 	y_inc^ = pos.y
	// }
	//
	// if x_inc != nil {
	// 	last := g.font_instances.data[g.font_instances.len-1]
	// 	x_inc^ = last.pos_max.x
	// }
}

_line_height :: proc(font: Font, size: f32) -> f32 {
	g.fs.state_count = 1
	state := fs.__getState(&g.fs)
	state^ = {
		size    = size,
		font    = int(font),
	}

	_, _, lh := fs.VerticalMetrics(&g.fs)
	return lh
}
