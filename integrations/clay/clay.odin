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
			)

		case .Rectangle:
			config := render_command.config.rectangleElementConfig

			if config.cornerRadius != {} {
				log.errorf("TODO: rounded rectangles: %v", config.cornerRadius)
			}

			if config.color.a != 0 {
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y},
					size     = {bounding_box.width, bounding_box.height},
					color    = transmute(u32)linalg.array_cast(config.color, u8),
				)
			}

		case .ScissorStart:
			nais.scissor(u32(bounding_box.x), u32(bounding_box.y), u32(bounding_box.width), u32(bounding_box.height))

		case .ScissorEnd:
			nais.scissor_end()

		case .Border:
			config := render_command.config.borderElementConfig

			if config.left.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y + config.cornerRadius.topLeft},
					size     = {f32(config.left.width), bounding_box.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft},
					color    = transmute(u32)linalg.array_cast(config.left.color, u8),
				)
			}

			if config.right.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + bounding_box.width - f32(config.right.width), bounding_box.y + config.cornerRadius.topRight},
					size     = {f32(config.right.width), bounding_box.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight},
					color    = transmute(u32)linalg.array_cast(config.right.color, u8),
				)
			}

			if config.top.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.topLeft, bounding_box.y},
					size     = {bounding_box.width - config.cornerRadius.topLeft - config.cornerRadius.topRight, f32(config.top.width)},
					color    = transmute(u32)linalg.array_cast(config.top.color, u8),
				)
			}

			if config.bottom.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.bottomLeft, bounding_box.y + bounding_box.height - f32(config.bottom.width)},
					size     = {bounding_box.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight, f32(config.bottom.width)},
					color    = transmute(u32)linalg.array_cast(config.bottom.color, u8),
				)
			}

			if config.cornerRadius.topLeft > 0 || config.cornerRadius.topRight > 0 || config.cornerRadius.bottomLeft > 0 || config.cornerRadius.bottomRight > 0 {
				log.errorf("TODO: border radius: %v", config)
			}

		case .None: fallthrough

		case: 
			log.errorf("TODO: clay render command: %v", render_command.commandType)
		}
	}
}
