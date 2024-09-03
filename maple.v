module maple

import os
import strings
import strings.textscanner
import datatypes

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

fn split_array(value string) []string {
	mut values := []string{}
	mut builder := strings.new_builder(0)
	mut in_string := false
	mut prev := ` `
	mut brace_stack := datatypes.Stack[rune]{}

	for ch in value#[1..-1] {
		if ch == `'` && prev != `\\` {
			in_string = !in_string
		} else if !in_string {
			if ch == `,` && brace_stack.is_empty() {
				values << builder.str()
				builder = strings.new_builder(0)
				prev = ` `
				continue
			} else if ch == `{` || ch == `[` {
				brace_stack.push(ch)
			} else if ch == `}` || ch == `]` {
				peeked := brace_stack.peek() or { panic('Unexpected brace: ${ch}') }

				if (peeked == `{` && ch != `}`) || (peeked == `[` && ch != `]`) {
					panic('Mismatched brace: ${ch}')
				}

				brace_stack.pop() or { panic('Unexpected brace: ${ch}') }
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

pub fn deserialize(value string) ValueT {
	if value[0] == `{` && value[value.len - 1] == `}` {
		l := load(value.all_after_first('{').all_before_last('}')) or {
			println(err)
			panic('Failed to load table value: ${value}')
		}
		return l
	} else if value[0] == `[` && value[value.len - 1] == `]` {
		return split_array(value).map(|it| deserialize(it.trim_space()))
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
		panic('Invalid value: ${value}')
	}
}

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

pub const whitespace = ' \t\r\n\f'

pub fn load(code string) !map[string]ValueT {
	mut table := map[string]ValueT{}

	mut scanner := textscanner.new(code)
	mut ch := ` `
	mut buf := strings.new_builder(0)
	mut brace_stack := datatypes.Stack[rune]{}
	mut in_string := false
	mut buffered_key := ''

	for {
		ch = scanner.next()

		if ch == -1 {
			break
		} else if ch == `/` && scanner.peek() == `/` {
			for {
				ch = scanner.next()
				if ch == `\n` || ch == -1 {
					break
				}
			}
			continue
		} else if ch == `'` && scanner.peek_back() != `\\` {
			in_string = !in_string
		} else if !in_string && ch == `=` && brace_stack.is_empty() {
			if buf.len <= 0 {
				panic('Unexpected `=`')
			}
			buffered_key = buf.str().trim_space()
			buf = strings.new_builder(0)
			continue
		} else if !in_string && (ch == `;` || ch == `\n`) && buf.len > 0 && brace_stack.is_empty() && buffered_key.len != 0 {
			statement := buf.str()
			table[buffered_key] = deserialize(statement.trim_space())
			buf = strings.new_builder(0)
			buffered_key = ''
			continue
		} else if !in_string && (ch == `{` || ch == `[`) {
			brace_stack.push(ch)
		} else if !in_string && (ch == `}` || ch == `]`) {
			peeked := brace_stack.peek() or { panic('Unexpected brace: ${ch}') }

			if (peeked == `{` && ch != `}`) || (peeked == `[` && ch != `]`) {
				panic('Mismatched brace: ${ch}')
			}

			brace_stack.pop() or { panic('Unexpected brace: ${ch}') }

			if brace_stack.is_empty() && buffered_key.len != 0 {
				buf.write_rune(ch)
				statement := buf.str()
				table[buffered_key] = deserialize(statement.trim_space())
				buf = strings.new_builder(0)
				buffered_key = ''
				continue
			}
		}

		buf.write_rune(ch)
	}

	if !brace_stack.is_empty() {
		panic('Reached EOL before brace ending. Brace stack: ${brace_stack}')
	} else if in_string {
		panic('Reached EOL before string ending.')
	}

	// Check for a final variable
	if buffered_key.len != 0 {
		statement := buf.str()
		table[buffered_key] = deserialize(statement.trim_space())
	}

	return table
}

@[inline] pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)!
}
