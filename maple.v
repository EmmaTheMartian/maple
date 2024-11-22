module maple

import os
import strings
import strings.textscanner
import datatypes

// A sum type to represent any possible value in Maple
pub type ValueT = string | int | f32 | bool | map[string]ValueT | []ValueT

@[inline] pub fn (value ValueT) to_str() string { return value as string }
@[inline] pub fn (value ValueT) to_int() int { return value as int }
@[inline] pub fn (value ValueT) to_f32() f32 { return value as f32 }
@[inline] pub fn (value ValueT) to_bool() bool { return value as bool }
@[inline] pub fn (value ValueT) to_map() map[string]ValueT { return value as map[string]ValueT }
@[inline] pub fn (value ValueT) to_array() []ValueT { return value as []ValueT }

@[inline] pub fn (value ValueT) get(key string) ValueT {
	if value is map[string]ValueT {
		return value[key] or { panic('Failed to index map with key: ${key}') }
	}
	panic('Cannot invoke .get() on a non-map ValueT.')
}

@[inline] pub fn (m map[string]ValueT) get(key string) ValueT {
	return m[key] or { panic('Failed to index map with key: ${key}') }
}

@[inline] pub fn (value ValueT) str() string {
	match value {
		string { return value }
		int { return value.str() }
		f32 { return value.str() }
		bool { return value.str() }
		map[string]ValueT { return value.str() }
		[]ValueT { return value.str() }
	}
}

// Serialize a value to a string
pub fn (val ValueT) serialize() string {
	match val {
		string { return '\'${val}\'' }
		int { return val.str() }
		f32 { return val.str() }
		bool { return val.str() }
		map[string]ValueT {
			mut s := '{'
			for key, val_val in val {
				s += '${key} = ${val_val.serialize()};'
			}
			s += '}'
			return s
		}
		[]ValueT {
			mut s := '['
			for val_val in val {
				s += val_val.serialize() + ','
			}
			s += ']'
			return s
		}
	}
	panic('Unknown value kind, cannot serialize.')
}

// Represents an open brace on the brace stack. Used primarily for error messages.
struct Brace {
pub:
	line int
	col int
	ch rune
}

// Used to hold data regarding line, column, and brace stack.
// Used primarily for descriptive error messages.
pub struct DeserializationContext {
pub mut:
	line int = 1
	col int = 1
	brace_stack datatypes.Stack[Brace] = datatypes.Stack[Brace]{}
	in_string bool
	string_start_line int = 1
	string_start_col int = 1
}

// Splits a serialized array.
fn split_array(value string, mut con DeserializationContext) []string {
	mut values := []string{}
	mut builder := strings.new_builder(0)
	mut prev := ` `

	for ch in value#[1..-1] {
		if ch == `'` && prev != `\\` {
			con.in_string = !con.in_string
		} else if !con.in_string {
			if ch == `,` && con.brace_stack.is_empty() {
				values << builder.str()
				builder = strings.new_builder(0)
				prev = ` `
				continue
			} else if ch == `{` || ch == `[` {
				con.brace_stack.push(Brace{con.line, con.col, ch})
			} else if ch == `}` || ch == `]` {
				peeked := con.brace_stack.peek() or {
					panic('Unexpected brace: ${ch} (at ${con.line}:${con.col})')
				}

				if (peeked.ch == `{` && ch != `}`) || (peeked.ch == `[` && ch != `]`) {
					panic('Mismatched brace: ${ch} (at ${con.line}:${con.col})')
				}

				con.brace_stack.pop() or {
					panic('Unexpected brace: ${ch} (at ${con.line}:${con.col})')
				}
			}
		}
		builder.write_u8(ch)
		prev = ch
	}

	s := builder.str().trim_space()
	if s.len > 0 {
		values << s
	}

	return values
}

// Deserialize a value to a ValueT. See maple.laod for deserializing more than just a value.
pub fn deserialize(value string, mut con DeserializationContext) ValueT {
	if value[0] == `{` && value[value.len - 1] == `}` {
		l := load(value.all_after_first('{').all_before_last('}')) or {
			println(err)
			panic('Failed to load table value: ${value} (at ${con.line}:${con.col})')
		}
		return l
	} else if value[0] == `[` && value[value.len - 1] == `]` {
		return split_array(value, mut con).map(fn [mut con] (it string) ValueT {
			return deserialize(it.trim_space(), mut con)
		})
	} else if value[0] == `'` && value[value.len - 1] == `'` {
		return value.substr_ni(1, -1)
	} else if value == 'true' {
		return true
	} else if value == 'false' {
		return false
	} else if value.is_int() {
		return value.int()
	} else if value.count('.') == 1 && value.before('.').is_int() && value.after('.').is_int() {
		return value.f32()
	} else {
		panic('Invalid value: ${value} (at ${con.line}:${con.col})')
	}
}

// Serialize data to a string
pub fn save(data map[string]ValueT) string {
	// We set an initial buffer of 1024 here because it will prevent smaller configs
	// from needing to grow_len so often.
	mut string_builder := strings.new_builder(1024)
	for key, value in data {
		serialized := value.serialize()
		string_builder.write_string('${key} = ${serialized}')
		if serialized[serialized.len - 1] != `}` && serialized[serialized.len - 1] != `]` {
			string_builder.write_rune(`;`)
		}
	}
	return string_builder.str()
}

// Save a map[string]ValueT to a file
pub fn save_file(fp string, data map[string]ValueT) ! {
	mut file := os.create(fp)!
	defer { file.close() }
	for key, value in data {
		serialized := value.serialize()
		file.write_string('${key} = ${serialized}')!
		if serialized[serialized.len - 1] != `}` && serialized[serialized.len - 1] != `]` {
			file.write_string(';')!
		}
	}
}

// Any form of whitespace recognized by the deserializer
pub const whitespace = ' \t\r\n\f'

// Deserialize code to a map[string]ValueT
pub fn load(code string) !map[string]ValueT {
	mut context := DeserializationContext{ }
	mut table := map[string]ValueT{}

	mut scanner := textscanner.new(code)
	mut ch := ` `
	mut buf := strings.new_builder(0)
	mut buffered_key := ''

	for {
		ch = scanner.next()

		if ch == `\n` {
			context.col = 1
			context.line++
		}

		if ch == -1 {
			break
		} else if !context.in_string && ch == `/` && scanner.peek() == `/` {
			for {
				ch = scanner.next()
				if ch == `\n` || ch == -1 {
					break
				}
			}
			continue
		} else if ch == `'` && scanner.peek_back() != `\\` {
			if buffered_key.len == 0 {
				panic('Unexpected string (at ${context.line}:${context.col})')
			}
			context.in_string = !context.in_string
			if context.in_string {
				context.string_start_line = context.line
				context.string_start_col = context.col
			} else {
				context.string_start_line = -1
				context.string_start_col = -1
			}
		} else if !context.in_string && ch == `=` && context.brace_stack.is_empty() {
			if buf.len <= 0 {
				panic('Unexpected `=` (at ${context.line}:${context.col})')
			}
			buffered_key = buf.str().trim_space()
			buf = strings.new_builder(0)
			continue
		} else if !context.in_string && (ch == `;` || ch == `\n`) && buf.len > 0 && context.brace_stack.is_empty() && buffered_key.len != 0 {
			statement := buf.str()
			table[buffered_key] = deserialize(statement.trim_space(), mut context)
			buf = strings.new_builder(0)
			buffered_key = ''
			continue
		} else if !context.in_string && (ch == `{` || ch == `[`) {
			context.brace_stack.push(Brace{context.line, context.col, ch})
		} else if !context.in_string && (ch == `}` || ch == `]`) {
			peeked := context.brace_stack.peek() or {
				panic('Unexpected brace: ${ch} (at ${context.line}:${context.col})')
			}

			if (peeked.ch == `{` && ch != `}`) || (peeked.ch == `[` && ch != `]`) {
				panic('Mismatched brace: ${ch} (at ${context.line}:${context.col})')
			}

			context.brace_stack.pop() or {
				panic('Unexpected brace: ${ch} (at ${context.line}:${context.col})')
			}

			if context.brace_stack.is_empty() && buffered_key.len != 0 {
				buf.write_rune(ch)
				statement := buf.str()
				table[buffered_key] = deserialize(statement.trim_space(), mut context)
				buf = strings.new_builder(0)
				buffered_key = ''
				continue
			}
		}

		buf.write_rune(ch)
		context.col++
	}

	if !context.brace_stack.is_empty() {
		panic('Reached EOL before brace ending. Brace stack: ${context.brace_stack} (started at ${context.brace_stack.peek()!.line}:${context.brace_stack.peek()!.col})')
	} else if context.in_string {
		panic('Reached EOL before string ending (string started at ${context.string_start_line}:${context.string_start_col})')
	}

	// Check for a final variable
	if buffered_key.len != 0 {
		statement := buf.str()
		table[buffered_key] = deserialize(statement.trim_space(), mut context)
	}

	return table
}

// Load a map[string]ValueT from a file
@[inline] pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)!
}
