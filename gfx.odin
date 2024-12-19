package nais

import "core:math/linalg"

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

Camera :: struct {
	target: [2]f32,
	zoom: f32,
}

// TODO: what else does a camera api need?
// TODO: zoom feels off but I can't place it.

camera_set :: proc(c: Maybe(Camera)) {
	g_window.gfx.camera = c
	fresh()
	for r in g_window.gfx.renderers {
		r(Renderer_Resize{})
	}
}

// PERF: every renderer calls this on every resize, is that expensive, probably not?
@(private)
_camera_matrix :: proc(sz: [2]f32, multiplier: f32) -> matrix[4,4]f32 {
	c, has_c := g_window.gfx.camera.?
	if has_c {
		c.target *= multiplier
	} else {
		c.target = sz * .5
		c.zoom = 1
	}

	zoom_offset := (1. - c.zoom) * c.target
	translation := zoom_offset - sz * .5 + c.target

	transformation := linalg.matrix_ortho3d(0, sz.x, sz.y, 0, -1, 1)
	transformation *= linalg.matrix4_translate_f32({translation.x, translation.y, 0})
	transformation *= linalg.matrix4_scale(c.zoom)

	return transformation
}

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
		fresh()
	}
	g_window.gfx.curr_renderer = r
}

fresh :: proc(loc := #caller_location) {
	f := &g_window.gfx.frame

	if g_window.gfx.curr_renderer != nil {
		// log.info("fresh", loc.procedure)
		g_window.gfx.curr_renderer(Renderer_Flush{pass=f.pass})

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

	if f.pass != nil {
		wgpu.RenderPassEncoderSetScissorRect(f.pass, f.scissor.x, f.scissor.y, f.scissor.w, f.scissor.h)
	}
}

scissor :: proc(x, y, w, h: u32) {
	f := &g_window.gfx.frame

	// TODO:
	when ODIN_OS == .JS {
		dpiu :: 0
	} else {
		dpi := dpi()
		assert(dpi.x == dpi.y)
		dpiu := u32(dpi.x)
	}

	if f.scissor != {x * dpiu, y * dpiu, w * dpiu, h * dpiu} {
		f.scissor = {x * dpiu, y * dpiu, w * dpiu, h * dpiu}
		fresh()
	}
}

scissor_end :: proc() {
	f := &g_window.gfx.frame

	if f.scissor != {0, 0, g_window.gfx.config.width, g_window.gfx.config.height} {
		f.scissor = {0, 0, g_window.gfx.config.width, g_window.gfx.config.height}
		fresh()
	}
}
