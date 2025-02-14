package nais_integrations_clay

import "core:log"
import "core:math/linalg"
import "core:math"

// TODO: this path is not going to be correct.
import clay "../../../pkg/clay"

import nais "../.."

measure_text :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, _: rawptr) -> clay.Dimensions {
	context = nais.default_context()

	bounds := nais.measure_text(
		string(text.chars[:text.length]),
		pos     = 0,
		size    = f32(config.fontSize),
		font    = nais.Font(config.fontId),
		spacing = f32(config.letterSpacing),
		align_v = .Top,
	)

	return {
		width  = bounds.width,
		height = bounds.max.y - bounds.min.y,
	}
}

color :: proc(color: [4]f32) -> u32 {
	color := color
	color = color.bgra
	return transmute(u32)linalg.array_cast(color, u8)
}

render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0..<i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(render_commands, i)
		bounding_box   := render_command.boundingBox

		#partial switch render_command.commandType {
		case .Text:
			config := render_command.renderData.text
			text   := string(config.stringContents.chars[:config.stringContents.length])

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
			config := render_command.renderData.rectangle

			if config.cornerRadius != {} {
				radius := config.cornerRadius.topLeft * 2 / min(bounding_box.width, bounding_box.height)
				nais.draw_rectangle_rounded(
					{bounding_box.x, bounding_box.y, bounding_box.width, bounding_box.height},
					radius,
					8,
					color(config.backgroundColor),
				)
			} else {
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y},
					size     = {bounding_box.width, bounding_box.height},
					color    = color(config.backgroundColor),
				)
			}

		case .ScissorStart:
			nais.scissor(u32(bounding_box.x), u32(bounding_box.y), u32(bounding_box.width), u32(bounding_box.height))

		case .ScissorEnd:
			nais.scissor_end()

		case .Border:
			config := render_command.renderData.border

			if config.width.left > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y + config.cornerRadius.topLeft},
					size     = {f32(config.width.left), bounding_box.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft},
					color    = color(config.color),
				)
			}

			if config.width.right > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + bounding_box.width - f32(config.width.right), bounding_box.y + config.cornerRadius.topRight},
					size     = {f32(config.width.right), bounding_box.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight},
					color    = color(config.color),
				)
			}

			if config.width.top > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.topLeft, bounding_box.y},
					size     = {bounding_box.width - config.cornerRadius.topLeft - config.cornerRadius.topRight, f32(config.width.top)},
					color    = color(config.color),
				)
			}

			if config.width.bottom > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.bottomLeft, bounding_box.y + bounding_box.height - f32(config.width.bottom)},
					size     = {bounding_box.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight, f32(config.width.bottom)},
					color    = color(config.color),
				)
			}

			if config.cornerRadius.topLeft > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + config.cornerRadius.topLeft), math.round(bounding_box.y + config.cornerRadius.topLeft)},
					math.round(config.cornerRadius.topLeft - f32(config.width.top)),
					config.cornerRadius.topLeft,
					180,
					270,
					10,
					color(config.color),
				)
			}
			
			if config.cornerRadius.topRight > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + bounding_box.width - config.cornerRadius.topRight), math.round(bounding_box.y + config.cornerRadius.topRight)},
					math.round(config.cornerRadius.topRight - f32(config.width.top)),
					config.cornerRadius.topRight,
					270,
					360,
					10,
					color(config.color),
				)
			}

			if config.cornerRadius.bottomLeft > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + config.cornerRadius.bottomLeft), math.round(bounding_box.y + bounding_box.height - config.cornerRadius.bottomLeft)},
					math.round(config.cornerRadius.bottomLeft - f32(config.width.top)),
					config.cornerRadius.bottomLeft,
					90,
					180,
					10,
					color(config.color),
				)
			}

			if config.cornerRadius.bottomRight > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + bounding_box.width - config.cornerRadius.bottomRight), math.round(bounding_box.y + bounding_box.height - config.cornerRadius.bottomRight)},
					math.round(config.cornerRadius.bottomRight - f32(config.width.bottom)),
					config.cornerRadius.bottomRight,
					.1,
					90,
					10,
					color(config.color),
				)
			}

		case .None:

		case: 
			log.errorf("TODO: clay render command: %v", render_command.commandType)
		}
	}
}
