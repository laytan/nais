package nais

import "core:log"
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
	size:     [2]f32,
	target:   Maybe([2]f32),
	zoom:     f32,
	invert_y: bool,
}

camera_set :: proc(c: Maybe(Camera)) {
	if g_window.gfx.camera == c {
		return
	}

	g_window.gfx.camera = c
	fresh()
	for r in g_window.gfx.renderers {
		r(Renderer_Resize{})
	}
}

camera_view :: proc() -> [2]f32 {
	c := g_window.gfx.camera.?
	return c.size * c.zoom
}

// PERF: every renderer calls this on every resize, is that expensive, probably not?
@(private)
_camera_matrix :: proc(sz: [2]f32) -> matrix[4,4]f32 {
	c, _ := g_window.gfx.camera.?

	target := c.target.? or_else sz * .5

	if c.zoom == 0 {
		c.zoom = 1
	}

	if c.size == 0 {
		c.size = sz
	}

	extents := c.size * .5 * c.zoom
	lower   := target - extents
	upper   := target + extents
	sz      := upper - lower

	if !c.invert_y {
		upper.y, lower.y = lower.y, upper.y
	}

	return linalg.matrix_ortho3d_f32(lower.x, upper.x, lower.y, upper.y, -1, 1)
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
		wgpu.RenderPassEncoderSetScissorRect(f.pass, f.scissor[0], f.scissor[1], f.scissor[2], f.scissor[3])
	}
}

scissor :: proc(x, y, w, h: u32, loc := #caller_location) {
	f := &g_window.gfx.frame

	dpi := dpi()
	assert(dpi.x == dpi.y)
	dpiu := u32(dpi.x)

	new_scissor := [4]u32{x * dpiu, y * dpiu, w * dpiu, h * dpiu}

	if new_scissor.x > g_window.gfx.config.width {
		log.warnf("scissor out of bounds: X of %v is greater than frame buffer width of %v, solution: X = frame buffer width", new_scissor.x, g_window.gfx.config.width, location=loc)
		new_scissor.x = g_window.gfx.config.width
	}

	if new_scissor.x + new_scissor.z > g_window.gfx.config.width {
		log.errorf("scissor out of bounds: X of %v + width of %v is greater than frame buffer width of %v, solution: no scissor", new_scissor.x, new_scissor.z, g_window.gfx.config.width, location=loc)
		return
	}

	if new_scissor.y > g_window.gfx.config.height {
		log.warnf("scissor out of bounds: Y of %v is greater than frame buffer height of %v, solution: clamping", new_scissor.y, g_window.gfx.config.height, location=loc)
		new_scissor.y = g_window.gfx.config.height
	}

	if new_scissor.y + new_scissor.w > g_window.gfx.config.height {
		log.errorf("scissor out of bounds: Y of %v + height of %v is greater than frame buffer height of %v, solution: no scissor", new_scissor.y, new_scissor.w, g_window.gfx.config.height, location=loc)
		return
	}

	if f.scissor != new_scissor {
		f.scissor = new_scissor
		fresh()
	}
}

scissor_end :: proc() {
	f := &g_window.gfx.frame

	full_scissor := [4]u32{0, 0, g_window.gfx.config.width, g_window.gfx.config.height}
	if f.scissor != full_scissor {
		f.scissor = full_scissor
		fresh()
	}
}
