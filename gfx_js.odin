//+private
package nais

import "core:strings"

import "vendor:wgpu"

__gfx_init :: proc() {}

__gfx_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return wgpu.InstanceCreateSurface(
		instance,
		&wgpu.SurfaceDescriptor{
			nextInChain = &wgpu.SurfaceDescriptorFromCanvasHTMLSelector{
				sType = .SurfaceDescriptorFromCanvasHTMLSelector,
				selector = "#wgpu-canvas",
			},
		},
	)
}
