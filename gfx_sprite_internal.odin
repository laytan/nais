//+private
package nais

import sa     "core:container/small_array"
import        "core:log"
import        "core:math/linalg"

import stbrp "vendor:stb/rect_pack"
import       "vendor:wgpu"

MAX_SPRITES :: 56_000

@(private="file")
g := struct{
	rp:           stbrp.Context,
	sprites:      #soa[dynamic]_Sprite,
	free_sprites: [dynamic]int,

	sprite_data:  sa.Small_Array(MAX_SPRITES, _Sprite_Data),

	constant_buffer:  wgpu.Buffer,
	atlas:            wgpu.Texture,
	atlas_view:       wgpu.TextureView,
	sprite_buffer:    wgpu.Buffer,
	sampler:          wgpu.Sampler,
	bindgroup:        wgpu.BindGroup,
	bindgroup_layout: wgpu.BindGroupLayout,
	module:           wgpu.ShaderModule,
	pipeline_layout:  wgpu.PipelineLayout,
	pipeline:         wgpu.RenderPipeline,
}{}

_Sprite :: struct {
	rect: stbrp.Rect,
	pxs:  [][4]u8 `fmt:"-"`,
}

_Sprite_Data :: struct {
	location: [2]f32,
	size:     [2]f32,
	using u:  Sprite_Data,
}

@(private="file")
Constants :: struct #packed {
	texture_size:   [2]f32,
	_:              [8]u8,
	transformation: matrix[4, 4]f32,
}
#assert(size_of(Constants) % 16 == 0)

_gfx_init_sprite :: proc() {
	g.rp.width               = 400
	g.rp.height              = 400
	g.sprites.allocator      = context.allocator
	g.free_sprites.allocator = context.allocator

	device := g_window.gfx.config.device

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.constant_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "Constants",
		usage = { .Uniform, .CopyDst },
		size  = size_of(Constants),
	})

	_gfx_sprite_write_consts()

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.atlas = wgpu.DeviceCreateTexture(device, &{
		usage         = { .CopyDst, .TextureBinding },
		dimension     = ._2D,
		size          = { u32(g.rp.width), u32(g.rp.height), 1 },
		format        = .BGRA8Unorm,
		mipLevelCount = 1,
		sampleCount   = 1,
	})

	g.atlas_view = wgpu.TextureCreateView(g.atlas, nil)

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.sprite_buffer = wgpu.DeviceCreateBuffer(device, &{
		label = "Sprites",
		usage = { .CopyDst, .Storage },
		size  = size_of(_Sprite_Data) * MAX_SPRITES,
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.sampler = wgpu.DeviceCreateSampler(device, &{
		addressModeU  = .ClampToEdge,
		addressModeV  = .ClampToEdge,
		addressModeW  = .ClampToEdge,
		magFilter     = .Linear,
		minFilter     = .Linear,
		mipmapFilter  = .Linear,
		lodMinClamp   = 0,
		lodMaxClamp   = 1,
		compare       = .Undefined,
		maxAnisotropy = 1,
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.bindgroup_layout = wgpu.DeviceCreateBindGroupLayout(device, &{
		entryCount = 4,
		entries    = raw_data([]wgpu.BindGroupLayoutEntry{
			{
				binding    = 0,
				visibility = { .Vertex, .Fragment },
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
					minBindingSize = size_of(_Sprite_Data) * MAX_SPRITES,
				},
			},
			{
				binding    = 2,
				visibility = { .Fragment },
				texture    = {
					sampleType    = .Float,
					viewDimension = ._2D,
					multisampled  = false,
				},
			},
			{
				binding    = 3,
				visibility = { .Fragment },
				sampler    = {
					type = .Filtering,
				},
			},
		}),
	})

	g.bindgroup = wgpu.DeviceCreateBindGroup(device, &{
		layout     = g.bindgroup_layout,
		entryCount = 4,
		entries    = raw_data([]wgpu.BindGroupEntry{
			{
				binding = 0,
				buffer  = g.constant_buffer,
				size    = size_of(Constants),
			},
			{
				binding = 1,
				buffer  = g.sprite_buffer,
				size    = size_of(_Sprite_Data) * MAX_SPRITES,
			},
			{
				binding     = 2,
				textureView = g.atlas_view,
			},
			{
				binding = 3,
				sampler = g.sampler,
			},
		}),
	})

	///////////////////////////////////////////////////////////////////////////////////////////////

	g.module = wgpu.DeviceCreateShaderModule(device, &{
		nextInChain = &wgpu.ShaderModuleWGSLDescriptor{
			sType = .ShaderModuleWGSLDescriptor,
			code  = #load("gfx_sprite.wgsl"),
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
		},
		fragment = &{
			module      = g.module,
			entryPoint  = "ps",
			targetCount = 1,
			targets     = &wgpu.ColorTargetState{
				format = .BGRA8Unorm,
				blend = &{
					color = {
						srcFactor = .One,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
					alpha = {
						srcFactor = .Zero,
						dstFactor = .One,
						operation = .Add,
					},
				},
				writeMask = wgpu.ColorWriteMaskFlags_All,
			},
		},
		primitive = {
			topology = .TriangleStrip,

		},
		multisample = {
			count = 1,
			mask  = 0xFFFFFFFF,
		},
	})

	@static rect: [1][4]u8
	rect[0] = 255
	load_sprite_from_pixels(rect[:], 1)

	append(&g_window.gfx.renderers, _sprite_renderer)
}

_gfx_sprite_write_consts :: proc() {
	queue  := g_window.gfx.queue

	window := window_size()

	transformation := linalg.matrix_ortho3d(0, window.x, window.y, 0, -1, 1)// * linalg.matrix4_scale_f32({1/dpi.x, 1/dpi.y, 1})

	constants := Constants{ 
		texture_size   = { 1. / f32(g.rp.width), 1. / f32(g.rp.height) },
		transformation = transformation,
	}

	wgpu.QueueWriteBuffer(queue, g.constant_buffer, 0, &constants, size_of(constants))
}

_sprite_renderer :: proc(ev: Renderer_Event) {
	switch e in ev {
	case Renderer_Resize:
		_gfx_sprite_write_consts()

	case Renderer_Flush:
		if sa.len(g.sprite_data) == 0 {
			return
		}

		log.debugf("drawing %v sprites", sa.len(g.sprite_data))

		queue  := g_window.gfx.queue

		wgpu.QueueWriteBuffer(queue, g.sprite_buffer, 0, &g.sprite_data.data, uint(size_of(_Sprite_Data)*sa.len(g.sprite_data)))

		wgpu.RenderPassEncoderSetPipeline(e.pass, g.pipeline)
		wgpu.RenderPassEncoderSetBindGroup(e.pass, 0, g.bindgroup)

		wgpu.RenderPassEncoderDraw(e.pass, 4, u32(sa.len(g.sprite_data)), 0, 0)

		sa.clear(&g.sprite_data)

	case Renderer_Frame:
		assert(sa.len(g.sprite_data) == 0)
	}
}

_load_sprite_from_pixels :: proc(pixels: [][4]u8, width: int) -> Sprite {
	sprite: _Sprite
	sprite.pxs = pixels
	sprite.rect.w = stbrp.Coord(width) + 1
	sprite.rect.h = stbrp.Coord(len(pixels) / width) + 1
	log.debugf("%#v", sprite)
	append(&g.sprites, sprite)
	_gfx_sprite_update_atlas()
	return (Sprite)(len(g.sprites)-1)
}

_gfx_sprite_update_atlas :: proc() {
	nodes := make([]stbrp.Node, g.rp.width, context.temp_allocator)
	stbrp.init_target(&g.rp, g.rp.width, g.rp.height, raw_data(nodes), i32(len(nodes)))
	if stbrp.pack_rects(&g.rp, &g.sprites[0].rect, i32(len(g.sprites))) == 0 {
		// Try again with bigger area.
		g.rp.width  *= 2
		g.rp.height *= 2
		_gfx_sprite_update_atlas()
		return
	}

	log.debugf("%#v\n%#v", g.sprites[0], g.sprites[1] if len(g.sprites) > 1 else _Sprite{})

	aw := int(g.rp.width)
	// ah := int(g.rp.height)
	texture_data := make([][4]u8, g.rp.width * g.rp.height, context.temp_allocator)
	for sprite, sprite_i in g.sprites {
		assert(!!sprite.rect.was_packed)
		w := int(sprite.rect.w - 1)
		h := int(sprite.rect.h - 1)
		x := int(sprite.rect.x)
		y := int(sprite.rect.y)
		yi := y * aw
		log.debug(w, h, y, yi)

		for i in 0..<h {
			defer yi += aw
			log.debugf("%v %v <- %v %v, %v", sprite_i, yi+x, i*w, w, sprite.pxs[i*w:][:w])
			copy(texture_data[yi+x:], sprite.pxs[i*w:][:w])
		}
	}

	log.debugf("%#v", texture_data[:20])

	if i32(wgpu.TextureGetWidth(g.atlas)) != g.rp.width || i32(wgpu.TextureGetHeight(g.atlas)) != g.rp.height {
		unimplemented("growing the atlas")
	}

	wgpu.QueueWriteTexture(
		g_window.gfx.queue,
		&{
			texture  = g.atlas,
		},
		raw_data(texture_data),
		uint(g.rp.width*g.rp.height * size_of([4]u8)),
		&{
			bytesPerRow  = u32(g.rp.width) * size_of([4]u8),
			rowsPerImage = u32(g.rp.height),
		},
		&{
			width              = u32(g.rp.width),
			height             = u32(g.rp.height),
			depthOrArrayLayers = 1,
		},
	)
}

_draw_sprite_data :: proc(_sprite: Sprite, data: Sprite_Data, flush := true) {
	sprite := g.sprites[int(_sprite)]
	assert(!!sprite.rect.was_packed)
	assert(sprite.rect.w > 0)
	assert(sprite.rect.h > 0)

	_gfx_swap_renderer(_sprite_renderer, flush)

	added := sa.append(&g.sprite_data, _Sprite_Data{
		location = linalg.array_cast([2]stbrp.Coord{sprite.rect.x, sprite.rect.y}, f32),
		size     = {f32(sprite.rect.w) - 1, f32(sprite.rect.h) - 1},
		u = data,
	})
	log.assertf(added, "maximum sprites of %v exceeded", MAX_SPRITES)
}
