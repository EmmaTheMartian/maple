module maple

import os
import strings
import strings.textscanner
import datatypes

// A sum type to represent any possible value in Maple
pub type ValueT = []ValueT
	| bool
	| f64
	| f32
	| i64
	| int
	| i32
	| i16
	| i8
	| map[string]ValueT
	| string
	| u64
	| u32
	| u16
	| u8

@[inline] pub fn (v ValueT) array() []ValueT { return v as []ValueT }
@[inline] pub fn (v ValueT) bool() bool { return v as bool }
@[inline] pub fn (v ValueT) f64() f64 { return v as f64 }
@[inline] pub fn (v ValueT) f32() f32 { return v as f32 }
@[inline] pub fn (v ValueT) i64() i64 { return v as i64 }
@[inline] pub fn (v ValueT) int() int { return v as int }
@[inline] pub fn (v ValueT) i32() i32 { return v as i32 }
@[inline] pub fn (v ValueT) i16() i16 { return v as i16 }
@[inline] pub fn (v ValueT) i8() i8 { return v as i8 }
@[inline] pub fn (v ValueT) map() map[string]ValueT { return v as map[string]ValueT }
@[inline] pub fn (v ValueT) u64() u64 {
	match v {
		u64 { return v }
		else {
			return v as u64
		}
	}
}
@[inline] pub fn (v ValueT) u32() u32 { return v as u32 }
@[inline] pub fn (v ValueT) u16() u16 { return v as u16 }
@[inline] pub fn (v ValueT) u8() u8 { return v as u8 }

@[inline]
pub fn (v ValueT) str() string {
	match v {
		map[string]ValueT {
			return ValueT(v).serialize()
		}
		[]ValueT {
			return ValueT(v).serialize()
		}
		else {
			return v as string
		}
	}
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_str() string {
	return value as string
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_int() int {
	return value as int
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_f32() f32 {
	return value as f32
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_bool() bool {
	return value as bool
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_map() map[string]ValueT {
	return value as map[string]ValueT
}

@[inline; deprecated; deprecated_after: '2025-7-18']
pub fn (value ValueT) to_array() []ValueT {
	return value as []ValueT
}

@[inline]
pub fn (value ValueT) get(key string) ValueT {
	if value is map[string]ValueT {
		return value[key] or { panic('Failed to index map with key: ${key}') }
	}
	panic('Cannot invoke .get() on a non-map ValueT.')
}

@[inline]
pub fn (m map[string]ValueT) get(key string) ValueT {
	return m[key] or { panic('Failed to index map with key: ${key}') }
}

@[params]
pub struct SerializeOptions {
pub:
	indents int
	indent_str string = '\t'
}

// serialize converts a value to a parsable string.
pub fn (value ValueT) serialize(opts SerializeOptions) string {
	match value {
		[]ValueT {
			indent_string := opts.indent_str.repeat(opts.indents + 1)
			mut s := '[\n'
			for val in value {
				s += indent_string + val.serialize(SerializeOptions{
					...opts
					indents: opts.indents + 1
				}) + ',\n'
			}
			return '${s}${opts.indent_str.repeat(opts.indents)}]'
		}
		bool { return value.str() }
		f64 { return value.str() }
		f32 { return value.str() }
		i64 { return value.str() }
		int { return value.str() }
		i32 { return value.str() }
		i16 { return value.str() }
		i8 { return value.str() }
		map[string]ValueT {
			indent_string := opts.indent_str.repeat(opts.indents + 1)
			indented_opts := SerializeOptions{
				...opts
				indents: opts.indents + 1
			}
			mut s := '{\n'
			for key, val in value {
				s += '${indent_string}${key} = ${val.serialize(indented_opts)}\n'
			}
			return '${s}${opts.indent_str.repeat(opts.indents)}}'
		}
		string { return '\'${value}\'' }
		u64 { return value.str() }
		u32 { return value.str() }
		u16 { return value.str() }
		u8 { return value.str() }
	}
}

// Brace represents an open brace on the brace stack. Primarily for making
// descriptive error messages.
struct Brace {
pub:
	line int
	col  int
	ch   rune
}

// DeserializationContext is used to hold data regarding line, column, and brace
// stack. Primarily for making descriptive error messages.
pub struct DeserializationContext {
pub mut:
	line              int                    = 1
	col               int                    = 1
	brace_stack       datatypes.Stack[Brace] = datatypes.Stack[Brace]{}
	in_string         bool
	string_kind       rune
	string_start_line int = 1
	string_start_col  int = 1
}

// split_array splits a serialized array, only used internally.
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

// deserialize deserializes a value to a ValueT. See maple.load for deserializing more than just a value.
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
	} else if (value[0] == `'` && value[value.len - 1] == `'`)
		|| (value[0] == `"` && value[value.len - 1] == `"`) {
		return value.substr_ni(1, -1)
	} else if value == 'true' {
		return true
	} else if value == 'false' {
		return false
	} else if value.is_int() {
		if value[0] == `-` {
			return value.u64()
		} else {
			return value.i64()
		}
	} else if value.count('.') == 1 && value.before('.').is_int() && value.after('.').is_int() {
		return value.f64()
	} else {
		panic('Invalid value: ${value} (at ${con.line}:${con.col})')
	}
}

// save serializes the data to a string
pub fn save(data map[string]ValueT) string {
	// We set an initial buffer of 1024 here because it will prevent smaller configs
	// from needing to grow_len so often.
	mut string_builder := strings.new_builder(1024)
	for key, value in data {
		string_builder.write_string('${key} = ${value.serialize()}\n')
	}
	return string_builder.str()
}

// save_file saves a map[string]ValueT to a file
@[inline]
pub fn save_file(fp string, data map[string]ValueT) ! {
	mut file := os.create(fp)!
	defer { file.close() }
	file.write_string(save(data))!
}

// whitespace recognized by the deserializer
pub const whitespace = ' \t\r\n\f'

// load deserializes code to a map[string]ValueT
pub fn load(code string) !map[string]ValueT {
	mut context := DeserializationContext{}
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
		} else if (ch == `'` || ch == `"`) && scanner.peek_back() != `\\` {
			if context.in_string && context.string_kind != ch {
				buf.write_rune(ch)
				context.col++
				continue
			}

			if buffered_key.len == 0 {
				panic('Unexpected string (at ${context.line}:${context.col})')
			}

			context.in_string = !context.in_string
			context.string_kind = ch

			if context.in_string {
				context.string_start_line = context.line
				context.string_start_col = context.col
			} else {
				context.string_start_line = -1
				context.string_start_col = -1
			}
		} else if context.in_string {
			// We check for a string early so that we do not have to
			// spend a precious CPU cycle checking that in every if
			// check after this
			buf.write_rune(ch)
			context.col++
			continue
		} else if ch == `/` && scanner.peek() == `/` {
			for {
				ch = scanner.next()
				if ch == `\n` || ch == -1 {
					break
				}
			}
			continue
		} else if ch == `=` && context.brace_stack.is_empty() {
			if buf.len <= 0 {
				panic('Unexpected `=` (at ${context.line}:${context.col})')
			}
			buffered_key = buf.str().trim_space()
			buf = strings.new_builder(0)
			continue
		} else if (ch == `;` || ch == `\n`) && buf.len > 0 && context.brace_stack.is_empty()
			&& buffered_key.len != 0 {
			statement := buf.str()
			table[buffered_key] = deserialize(statement.trim_space(), mut context)
			buf = strings.new_builder(0)
			buffered_key = ''
			continue
		} else if ch == `{` || ch == `[` {
			context.brace_stack.push(Brace{context.line, context.col, ch})
		} else if ch == `}` || ch == `]` {
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
		top_ch := context.brace_stack.peek()!.ch
		kind := if top_ch == `[` {
			'array'
		} else if top_ch == `{` {
			'map'
		} else {
			'unknown brace type (${top_ch})'
		}
		panic('Reached EOL before ${kind} ending. Brace stack: ${context.brace_stack} (started at ${context.brace_stack.peek()!.line}:${context.brace_stack.peek()!.col})')
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

// load_file loads a map[string]ValueT from a file.
@[inline]
pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)!
}

// load_to_struct loads the given data and returns them as the given struct.
// based on https://github.com/vlang/v/blob/504ec54be1a2962f8e0e7de41e538584986e4423/vlib/x/json2/decoder.v#L84
pub fn load_to_struct[T](code string) !T {
	data := load(code)!
	mut t := T{}
	$if T is $struct {
		$for field in T.fields {
			mut skip_field := false
			mut maple_name := field.name

			for attr in field.attrs {
				if attr.contains('skip') {
					skip_field = true
				}
				if attr.contains('maple: ') {
					maple_name = attr.replace('maple: ', '')
					if maple_name == '-' {
						skip_field = true
					}
					break
				}
			}

			if !skip_field {
				$if field.is_enum {
					if v := data[maple_name] {
						t.$(field.name) = v.int()
					} else {
						$if field.is_option {
							t.$(field.name) = none
						}
					}
				} $else $if field.typ is u8 {
					t.$(field.name) = data[maple_name]!.u64()
				} $else $if field.typ is u16 {
					t.$(field.name) = data[maple_name]!.u64()
				} $else $if field.typ is u32 {
					t.$(field.name) = data[maple_name]!.u64()
				} $else $if field.typ is u64 {
					t.$(field.name) = data[maple_name]!.u64()
				} $else $if field.typ is int {
					t.$(field.name) = data[maple_name]!.int()
				} $else $if field.typ is i8 {
					t.$(field.name) = data[maple_name]!.int()
				} $else $if field.typ is i16 {
					t.$(field.name) = data[maple_name]!.int()
				} $else $if field.typ is i32 {
					t.$(field.name) = i32(data[field.name]!.i32())
				} $else $if field.typ is i64 {
					t.$(field.name) = data[maple_name]!.i64()
				} $else $if field.typ is ?u8 {
					if maple_name in data {
						t.$(field.name) = ?u8(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?i8 {
					if maple_name in data {
						t.$(field.name) = ?i8(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?u16 {
					if maple_name in data {
						t.$(field.name) = ?u16(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?i16 {
					if maple_name in data {
						t.$(field.name) = ?i16(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?u32 {
					if maple_name in data {
						t.$(field.name) = ?u32(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?i32 {
					if maple_name in data {
						t.$(field.name) = ?i32(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?u64 {
					if maple_name in data {
						t.$(field.name) = ?u64(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?i64 {
					if maple_name in data {
						t.$(field.name) = ?i64(data[maple_name]!.i64())
					}
				} $else $if field.typ is ?int {
					if maple_name in data {
						t.$(field.name) = ?int(data[maple_name]!.i64())
					}
				} $else $if field.typ is f32 {
					t.$(field.name) = data[maple_name]!.f32()
				} $else $if field.typ is ?f32 {
					if maple_name in data {
						t.$(field.name) = data[maple_name]!.f32()
					}
				} $else $if field.typ is f64 {
					t.$(field.name) = data[maple_name]!.f64()
				} $else $if field.typ is ?f64 {
					if maple_name in data {
						t.$(field.name) = data[maple_name]!.f64()
					}
				} $else $if field.typ is bool {
					t.$(field.name) = data[maple_name]!.bool()
				} $else $if field.typ is ?bool {
					if maple_name in data {
						t.$(field.name) = data[maple_name]!.bool()
					}
				} $else $if field.typ is string {
					t.$(field.name) = data[maple_name]!.str()
				} $else $if field.typ is ?string {
					if maple_name in data {
						t.$(field.name) = data[maple_name]!.str()
					}
				// } $else $if field.typ is time.Time {
				// 	t.$(field.name) = data[maple_name]!.to_time()!
				// } $else $if field.typ is ?time.Time {
				// 	if maple_name in data {
				// 		t.$(field.name) = data[maple_name]!.to_time()!
				// 	}
				} $else $if field.typ is ValueT {
					t.$(field.name) = data[maple_name]!
				} $else $if field.typ is ?ValueT {
					if maple_name in data {
						t.$(field.name) = data[maple_name]!
					}
				} $else $if field.is_array {
					arr := data[field.name]! as []ValueT
					decode_array_item(mut t.$(field.name), arr)
				} $else $if field.is_struct {
					t.$(field.name) = decode_struct(t.$(field.name), data[field.name]!.as_map())!
				} $else $if field.is_alias {
				} $else $if field.is_map {
					t.$(field.name) = decode_map(t.$(field.name), data[field.name]!.as_map())!
				} $else {
					return error("The type of `${field.name}` can't be decoded. Please open an issue at https://github.com/emmathemartian/maple/issues/")
				}
			}
		}
	} $else {
		return error("The type `${T.name}` can't be decoded.")
	}
	return t
}
