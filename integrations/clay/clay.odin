package nais_integrations_clay

import "core:log"
import "core:math/linalg"
import "core:math"

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
		align_v = .Baseline,
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
			config := render_command.config.textElementConfig
			text   := string(render_command.text.chars[:render_command.text.length])

			nais.draw_text(
				text    = text,
				pos     = {bounding_box.x, bounding_box.y},
				size    = f32(config.fontSize),
				color   = linalg.array_cast(config.textColor, u8),
				spacing = f32(config.letterSpacing),
				font    = nais.Font(config.fontId),
				align_v = .Baseline,
			)

		case .Rectangle:
			config := render_command.config.rectangleElementConfig

			if config.cornerRadius != {} {
				radius := config.cornerRadius.topLeft * 2 / min(bounding_box.width, bounding_box.height)
				nais.draw_rectangle_rounded(
					{bounding_box.x, bounding_box.y, bounding_box.width, bounding_box.height},
					radius,
					8,
					color(config.color),
				)
			} else if config.color.a > 0 {
				// TODO: add the alpha check in the nais renderer itself.
				nais.draw_rectangle(
					position = {bounding_box.x, bounding_box.y},
					size     = {bounding_box.width, bounding_box.height},
					color    = color(config.color),
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
					color    = color(config.left.color),
				)
			}

			if config.right.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + bounding_box.width - f32(config.right.width), bounding_box.y + config.cornerRadius.topRight},
					size     = {f32(config.right.width), bounding_box.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight},
					color    = color(config.right.color),
				)
			}

			if config.top.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.topLeft, bounding_box.y},
					size     = {bounding_box.width - config.cornerRadius.topLeft - config.cornerRadius.topRight, f32(config.top.width)},
					color    = color(config.top.color),
				)
			}

			if config.bottom.width > 0 {
				nais.draw_rectangle(
					position = {bounding_box.x + config.cornerRadius.bottomLeft, bounding_box.y + bounding_box.height - f32(config.bottom.width)},
					size     = {bounding_box.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight, f32(config.bottom.width)},
					color    = color(config.bottom.color),
				)
			}

			if config.cornerRadius.topLeft > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + config.cornerRadius.topLeft), math.round(bounding_box.y + config.cornerRadius.topLeft)},
					math.round(config.cornerRadius.topLeft - f32(config.top.width)),
					config.cornerRadius.topLeft,
					180,
					270,
					10,
					color(config.top.color),
				)
			}
			
			if config.cornerRadius.topRight > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + bounding_box.width - config.cornerRadius.topRight), math.round(bounding_box.y + config.cornerRadius.topRight)},
					math.round(config.cornerRadius.topRight - f32(config.top.width)),
					config.cornerRadius.topRight,
					270,
					360,
					10,
					color(config.top.color),
				)
			}

			if config.cornerRadius.bottomLeft > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + config.cornerRadius.bottomLeft), math.round(bounding_box.y + bounding_box.height - config.cornerRadius.bottomLeft)},
					math.round(config.cornerRadius.bottomLeft - f32(config.top.width)),
					config.cornerRadius.bottomLeft,
					90,
					180,
					10,
					color(config.bottom.color),
				)
			}

			if config.cornerRadius.bottomRight > 0 {
				nais.draw_ring(
					{math.round(bounding_box.x + bounding_box.width - config.cornerRadius.bottomRight), math.round(bounding_box.y + bounding_box.height - config.cornerRadius.bottomRight)},
					math.round(config.cornerRadius.bottomRight - f32(config.bottom.width)),
					config.cornerRadius.bottomRight,
					.1,
					90,
					10,
					color(config.bottom.color),
				)
			}

		case .None:

		case: 
			log.errorf("TODO: clay render command: %v", render_command.commandType)
		}
	}
}
