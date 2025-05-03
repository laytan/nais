package nais_integrations_clay

import "core:log"
import "core:math/linalg"
import "core:math"
import "core:slice"

import clay "pkg:clay"

import nais "../.."

measure_text :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, _: rawptr) -> clay.Dimensions {
	context = nais.ctx()

	text := string(text.chars[:text.length])

	w, h := nais.measure_text(
		text,
		size    = f32(config.fontSize),
		font    = nais.Font(config.fontId),
		spacing = f32(config.letterSpacing),
	)

	return {
		width  = w,
		height = h,
	}
}

color :: proc(color: [4]f32) -> u32 {
	color := color
	color = color.bgra
	return transmute(u32)linalg.array_cast(color, u8)
}

render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	// TODO: enable when treeDepth
	// batches := make([dynamic]i32, context.temp_allocator)
	//
	// for i in 0..<i32(render_commands.length) {
	// 	render_command := clay.RenderCommandArray_Get(render_commands, i)
	// 	if render_command.commandType == .ScissorStart {
	// 		append(&batches, i)
	// 	}
	// 	if render_command.commandType == .ScissorEnd {
	// 		append(&batches, i)
	// 	}
	// }
	// if len(batches) > 0 {
	// 	if batches[len(batches)-1] != render_commands.length-1 {
	// 		append(&batches, render_commands.length-1)
	// 	}
	// }
	//
	// start: i32
	// for batch, i in batches {
	// 	end := batch
	// 	defer start = batch + 1
	//
	// 	batch_slice := render_commands.internalArray[start:end]
	//
	// 	slice.sort_by(batch_slice, proc(a, b: clay.RenderCommand) -> bool {
	// 		assert(a.commandType != .ScissorStart)
	// 		assert(a.commandType != .ScissorEnd)
	//
	// 		assert(b.commandType != .ScissorStart)
	// 		assert(b.commandType != .ScissorEnd)
	//
	// 		if a.zIndex != b.zIndex {
	// 			return a.zIndex < b.zIndex
	// 		}
	//
	// 		if a.treeDepth != b.treeDepth {
	// 			return a.treeDepth < b.treeDepth
	// 		}
	//
	// 		return a.commandType < b.commandType
	// 	})
	// }

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

			nais.draw_rectangle(
				{bounding_box.x, bounding_box.y},
				{bounding_box.width, bounding_box.height},
				config.backgroundColor / 255,
				{config.cornerRadius.topLeft, config.cornerRadius.topRight, config.cornerRadius.bottomRight, config.cornerRadius.bottomLeft},
			)

		case .ScissorStart:
			nais.scissor(u32(bounding_box.x), u32(bounding_box.y), u32(bounding_box.width), u32(bounding_box.height))

		case .ScissorEnd:
			nais.scissor_end()

		case .Border:
			config := render_command.renderData.border

			nais.draw_rectangle_outline(
				{bounding_box.x, bounding_box.y},
				{bounding_box.width, bounding_box.height},
				config.color / 255,
				{config.cornerRadius.topLeft, config.cornerRadius.topRight, config.cornerRadius.bottomRight, config.cornerRadius.bottomLeft},
				linalg.to_f32([4]u16{config.width.left, config.width.right, config.width.bottom, config.width.top}),
			)

		case .Image:
			config := render_command.renderData.image
			nais.draw_sprite(
				nais.Sprite(uintptr(config.imageData)),
				position={bounding_box.x, bounding_box.y},
				scale=nais.scale_sprite(nais.Sprite(uintptr(config.imageData)), {bounding_box.width, bounding_box.height}),
			)

		case .None:

		case: 
			log.errorf("TODO: clay render command: %v", render_command.commandType)
		}
	}
}
