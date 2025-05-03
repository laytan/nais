package main

import      "core:text/edit"
import      "core:strings"
import      "core:math/linalg"
import      "core:log"
import ba   "core:container/bit_array"

import clay "pkg:clay"

import nais "../.."

Input :: struct {
	keys:     ba.Bit_Array,
	new_keys: ba.Bit_Array,
	scroll:   [2]f64,
	cursor:   [2]i32,
}

key_down :: proc(keys: ..nais.Key) -> (ok: bool) {
	for k in keys {
		if !ba.unsafe_get(&g.inp.keys, k) {
			return
		}
	}
	return true
}

key_down_any :: proc(keys: ..nais.Key) -> (ok: bool) {
	for k in keys {
		if ba.unsafe_get(&g.inp.keys, k) {
			return true
		}
	}
	return false
}

key_pressed :: proc(keys: ..nais.Key) -> (ok: bool) {
	for k in keys {
		if !ba.unsafe_get(&g.inp.new_keys, k) {
			return
		}
	}
	return true
}

key_pressed_any :: proc(keys: ..nais.Key) -> (ok: bool) {
	for k in keys {
		if ba.unsafe_get(&g.inp.new_keys, k) {
			return true
		}
	}
	return false
}

alt_down :: proc() -> bool {
	return key_down_any(.Left_Alt, .Right_Alt)
}

ctrl_down :: proc() -> bool {
	return key_down_any(.Left_Control, .Right_Control)
}

shift_down :: proc() -> bool {
	return key_down_any(.Left_Shift, .Right_Shift)
}

i_press_release :: proc(key: nais.Key, action: nais.Key_Action) {
	#partial switch key {
	case .Mouse_Left, .Mouse_Middle, .Mouse_Right:
		switch action {
		case .Released:
			ba.unset(&g.inp.keys,     key)
			ba.unset(&g.inp.new_keys, key)

		case .Pressed:
			ba.set(&g.inp.keys,     key)
			ba.set(&g.inp.new_keys, key)

		case:
			unreachable()
		}
	case:
		switch action {
		case .Released:
			ba.unset(&g.inp.keys,     key)
			ba.unset(&g.inp.new_keys, key)

		case .Pressed:
			ba.set(&g.inp.keys,     key)
			ba.set(&g.inp.new_keys, key)

			#partial switch key {
			case .Z:         
				if ctrl_down() {
					if shift_down() {
						edit.perform_command(&g.editor, .Redo)
					} else {
						edit.perform_command(&g.editor, .Undo)
					}
				}

			case .A:
				if ctrl_down() {
					edit.perform_command(&g.editor, .Select_All)
				}

			case .C:
				if ctrl_down() {
					edit.perform_command(&g.editor, .Copy)
				}

			case .X:
				if ctrl_down() {
					edit.perform_command(&g.editor, .Cut)
				}

			case .V:
				if ctrl_down() {
					edit.perform_command(&g.editor, .Paste)
				}

				// TODO:
				// Delete,
				// Delete_Word_Left,
				// Delete_Word_Right,

				// Start,
				// End,

				// Select_Start,
				// Select_End,

			case .Left:
				if ctrl_down() {
					curr := g.editor.selection[0]
					pos := strings.last_index_byte(string(g.builder.buf[:curr]), '\n')
					if pos == -1 {
						pos = 0
					}
					g.editor.line_start = pos + 1
				}

				if shift_down() {
					if alt_down() {
						edit.perform_command(&g.editor, .Select_Word_Left)
					} else if ctrl_down() {
						edit.perform_command(&g.editor, .Select_Line_Start)
					} else {
						edit.perform_command(&g.editor, .Select_Left)
					}
				} else if alt_down() {
					edit.perform_command(&g.editor, .Word_Left)
				} else if ctrl_down() {
					edit.perform_command(&g.editor, .Line_Start)
				} else {
					edit.perform_command(&g.editor, .Left)
				}

			case .Right:
				if ctrl_down() {
					curr := g.editor.selection[0]
					pos  := strings.index_byte(string(g.builder.buf[curr:]), '\n')
					if pos == -1 {
						pos = len(g.builder.buf)-1
					}
					g.editor.line_end = curr + pos
				}

				if shift_down() {
					if alt_down() {
						edit.perform_command(&g.editor, .Select_Word_Right)
					} else if ctrl_down() {
						edit.perform_command(&g.editor, .Select_Line_End)
					} else {
						edit.perform_command(&g.editor, .Select_Right)
					}
				} else if alt_down() {
					edit.perform_command(&g.editor, .Word_Right)
				} else if ctrl_down() {
					edit.perform_command(&g.editor, .Line_End)
				} else {
					edit.perform_command(&g.editor, .Right)
				}

			case .Up:
				curr     := g.editor.selection[0]
				line_idx := strings.last_index_byte(string(g.builder.buf[:curr]), '\n') + 1
				column   := curr-line_idx

				prev_line      := strings.last_index_byte(string(g.builder.buf[:max(0, line_idx-1) ]), '\n') + 1
				prev_prev_line := strings.last_index_byte(string(g.builder.buf[:max(0, prev_line-1)]), '\n') + 1

				g.editor.up_index = clamp(prev_line+column, prev_prev_line, len(g.builder.buf)-1)

				if shift_down() {
					edit.perform_command(&g.editor, .Select_Up)
				} else {
					edit.perform_command(&g.editor, .Up)
				}

			case .Down:
				curr := g.editor.selection[0]
				line_idx := strings.last_index_byte(string(g.builder.buf[:curr]), '\n') + 1
				column   := curr-line_idx

				next_line      := curr      + strings.index_byte(string(g.builder.buf[curr:]), '\n') + 1
				next_next_line := next_line + max(0, strings.index_byte(string(g.builder.buf[next_line:]), '\n'))

				g.editor.down_index = clamp(next_line+column, 0, next_next_line)

				if shift_down() {
					edit.perform_command(&g.editor, .Select_Down)
				} else {
					edit.perform_command(&g.editor, .Down)
				}

			case .Backspace: edit.perform_command(&g.editor, .Backspace)
			case .Enter:     edit.perform_command(&g.editor, .New_Line)

			case .Tab: edit.input_text(&g.editor, "    ")

			case .D:
				if ctrl_down() {
					clay.SetDebugModeEnabled(!clay.IsDebugModeEnabled())
				}

			case .R:
				if ctrl_down() {
					init_state()
				}
			}

		case:
			unreachable()
		}
	}
}
