package nais_integrations_clay

import "core:log"
import "core:math/linalg"

// TODO: this path is not going to be correct.
import clay "../../../pkg/clay"

import nais "../.."

measure_text :: proc "c" (text: ^clay.String, config: ^clay.TextElementConfig) -> clay.Dimensions {
	context = nais.default_context()

	bounds := nais.measure_text(
		string(text.chars[:text.length]),
		pos     = 0,
		size    = f32(config.fontSize),
		font    = nais.Font(config.fontId),
		spacing = f32(config.letterSpacing),
	)

	return {
		width  = bounds.width,
		height = bounds.max.y - bounds.min.y,
	}
}

render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0..<i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(render_commands, i)
		bounding_box   := render_command.boundingBox

		#partial switch render_command.commandType {
		case .Text:
			config := render_command.config.textElementConfig
			text   := string(render_command.text.chars[:render_command.text.length])

			nais.draw_text(
				text    = text,
				pos     = {bounding_box.x, bounding_box.y},
				size    = f32(config.fontSize),
				color   = linalg.array_cast(config.textColor, u8),
				spacing = f32(config.letterSpacing),
				font    = nais.Font(config.fontId),
				align_v = .Top,
			)

		case .Rectangle:
			config := render_command.config.rectangleElementConfig

			if config.cornerRadius != {} {
				log.warnf("TODO: rounded rectangles: %v", config.cornerRadius)
			}

			if config.color.a != 0 {
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y},
					size     = {bounding_box.width, bounding_box.height},
					color    = transmute(u32)linalg.array_cast(config.color, u8),
				)
			}

		case .ScissorStart, .ScissorEnd:

		case .None: fallthrough
		case: 
			log.panicf("unhandled clay render command: %v", render_command.commandType)
		}
	}
}
