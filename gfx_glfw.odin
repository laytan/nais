#+build !js
#+private
package nais

import "core:strings"

import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

__gfx_init :: proc() {
	level := wgpu.LogLevel.Debug if .Debug_Renderer in g_window.flags else wgpu.LogLevel.Warn
	wgpu.SetLogLevel(level)

	wgpu.SetLogCallback(proc "c" (wgpulevel: wgpu.LogLevel, message: string, user: rawptr) {
		context = g_window.ctx
		logger := context.logger
		if logger.procedure == nil {
			return
		}

		level := wgpu.ConvertLogLevel(wgpulevel)
		if level < logger.lowest_level {
			return
		}

		smessage := strings.concatenate({"[nais][wgpu]: ", string(message)}, context.temp_allocator)
		logger.procedure(logger.data, level, smessage, logger.options, {})
	}, nil)
}

__gfx_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return glfwglue.GetSurface(instance, g_window.impl.handle)
}
