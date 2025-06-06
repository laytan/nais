#+private
package nais

import "core:log"

import "vendor:wgpu"

_gfx_init :: proc() {
	__gfx_init()

	instance := wgpu.CreateInstance()
	if instance == nil {
		// TODO: show that webgpu is not supported in the browser.
		log.panicf("[nais][wgpu]: WebGPU is unsupported in this browser")
	}

	g_window.gfx.surface = __gfx_get_surface(instance)
	wgpu.InstanceRequestAdapter(instance, &{
		compatibleSurface = g_window.gfx.surface,
		powerPreference = .LowPower if .Low_Power in g_window.flags else .HighPerformance,
	}, { callback = _gfx_adapter_callback })
}

_gfx_adapter_callback :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: string, _, _: rawptr) {
	context = g_window.ctx

	if status != .Success {
		log.panicf("[nais][wgpu]: request adapter failed with status %v: %v", status, message)
	}
	assert(adapter != nil)

	wgpu.AdapterRequestDevice(adapter, &{
		deviceLostCallbackInfo = { callback = _gfx_device_lost_callback },
		uncapturedErrorCallbackInfo = { callback = _gfx_uncaptured_error_callback },
	}, { callback = _gfx_device_callback })
}

_gfx_device_lost_callback :: proc "c" (device: ^wgpu.Device, reason: wgpu.DeviceLostReason, message: string, _, _: rawptr) {
	// NOTE: should we request a new device?
	context = g_window.ctx
	log.panicf("[nais][wgpu]: device lost because of %v: %v", reason, message)
}

_gfx_uncaptured_error_callback :: proc "c" (device: ^wgpu.Device, type: wgpu.ErrorType, message: string, _, _: rawptr) {
	context = g_window.ctx
	log.panicf("[nais][wgpu]: uncaptured error %v: %v", type, message)
}

_gfx_device_callback :: proc "c" (status: wgpu.RequestDeviceStatus, device: wgpu.Device, message: string, _, _: rawptr) {
	context = g_window.ctx

	if status != .Success {
		log.panicf("[nais][wgpu]: request device failed with status %v: %v", status, message)
	}
	assert(device != nil)

	g_window.gfx.config.device = device
	g_window.gfx.queue = wgpu.DeviceGetQueue(device)

	wgpu.SurfaceConfigure(g_window.gfx.surface, &g_window.gfx.config)

	_gfx_init_default_renderers()

	_initialized_callback()
}

_gfx_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return __gfx_get_surface(instance)
}

_gfx_init_default_renderers :: proc() {
	_gfx_init_text()
	_gfx_init_sprite()
	_gfx_init_sdf()
}

// TODO: temporary.

_gfx_frame :: proc() {
	curr_texture := wgpu.SurfaceGetCurrentTexture(g_window.gfx.surface)
	curr_view    := wgpu.TextureCreateView(curr_texture.texture)

	// TODO: probably inefficient.

	encoder := wgpu.DeviceCreateCommandEncoder(g_window.gfx.config.device)
	pass := wgpu.CommandEncoderBeginRenderPass(encoder, &{
		colorAttachmentCount = 1,
		colorAttachments = raw_data([]wgpu.RenderPassColorAttachment{
			{
				view       = curr_view,
				loadOp     = .Clear,
				storeOp    = .Store,
				clearValue = g_window.gfx.background,
				depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
			},
		}),
	})

	g_window.gfx.frame = {
		texture = curr_texture,
		view    = curr_view,
		encoder = encoder,
		pass    = pass,
		scissor = {0, 0, g_window.gfx.config.width, g_window.gfx.config.height},
	}
	wgpu.RenderPassEncoderSetScissorRect(g_window.gfx.frame.pass, g_window.gfx.frame.scissor[0], g_window.gfx.frame.scissor[1], g_window.gfx.frame.scissor[2], g_window.gfx.frame.scissor[3])
	g_window.gfx.frame.buffers.allocator = context.temp_allocator
	// TODO: current renderer on frame struct
	g_window.gfx.curr_renderer = nil

	for r in g_window.gfx.renderers {
		r(Renderer_Frame{})
	}
}

_gfx_frame_end :: proc() {
	f := g_window.gfx.frame

	for r in g_window.gfx.renderers {
		r(Renderer_Flush{pass=f.pass})
	}

	wgpu.RenderPassEncoderEnd(f.pass)
	wgpu.RenderPassEncoderRelease(f.pass)

	buffer := wgpu.CommandEncoderFinish(f.encoder)
	defer wgpu.CommandBufferRelease(buffer)
	wgpu.QueueSubmit(g_window.gfx.queue, {buffer})

	wgpu.CommandEncoderRelease(f.encoder)
	wgpu.SurfacePresent(g_window.gfx.surface)
	wgpu.TextureViewRelease(f.view)
	wgpu.TextureRelease(f.texture.texture)

	g_window.gfx.frame = {}
	g_window.gfx.curr_renderer = nil
	// TODO: current renderer on frame
}
