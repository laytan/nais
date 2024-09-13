package nais

import "core:log"

import "vendor:wgpu"

// TODO: unify the way colors are done for the love of god.

Renderer_Event :: union {
	Renderer_Resize,
	Renderer_Flush,
	Renderer_Frame,
}

Renderer_Resize :: struct {
}

Renderer_Flush :: struct {
	pass: wgpu.RenderPassEncoder,
}

Renderer_Frame :: struct {}

Renderer :: #type proc(event: Renderer_Event)

background_set :: proc(color: [4]f64) {
	g_window.gfx.background = color
}

background :: proc() -> [4]f64 {
	return g_window.gfx.background
}

_gfx_swap_renderer :: proc(r: Renderer, flush: bool) {
	// TODO: not flushing can lead to loss, because the active renderer is changed while the one
	// it changes from still has things to draw.
	assert(flush, "badly implemented: not flushing")

	if flush && g_window.gfx.curr_renderer != nil && g_window.gfx.curr_renderer != r {
		f := &g_window.gfx.frame
		log.debug("flushing renderer", r)
		g_window.gfx.curr_renderer(Renderer_Flush{pass=f.pass})

		// TODO: probably inefficient.

		wgpu.RenderPassEncoderEnd(f.pass)
		wgpu.RenderPassEncoderRelease(f.pass)

		buffer := wgpu.CommandEncoderFinish(f.encoder)
		defer wgpu.CommandBufferRelease(buffer)

		wgpu.QueueSubmit(g_window.gfx.queue, {buffer})

		wgpu.CommandEncoderRelease(f.encoder)

		f.encoder = wgpu.DeviceCreateCommandEncoder(g_window.gfx.config.device)
		f.pass = wgpu.CommandEncoderBeginRenderPass(f.encoder, &{
			colorAttachmentCount = 1,
			colorAttachments = raw_data([]wgpu.RenderPassColorAttachment{
				{
					view       = f.view,
					loadOp     = .Load,
					storeOp    = .Store,
					depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
				},
			}),
		})
	}
	g_window.gfx.curr_renderer = r
}
