module maple

import os
import strings
import strings.textscanner

type ValueT = string | int | f32 | bool | map[string]ValueT | []ValueT

fn (val ValueT) serialize() string {
	match val {
		string { return val }
		int { return val.str() }
		f32 { return val.str() }
		bool { return val.str() }
		map[string]ValueT {
			mut s := '{'
			for key, val_val in val {
				s += '${key}=${val_val.serialize()},'
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
	println('splitting: ${value}')
	mut values := []string{}
	mut builder := strings.new_builder(0)
	mut in_string := false
	mut prev := ` `

	for ch in value#[1..-1] {
		if ch == `'` && prev != `\\` {
			in_string = !in_string
		} else if ch == `,` && !in_string {
			values << builder.str()
			builder = strings.new_builder(0)
			prev = ` `
			continue
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

fn deserialize(value string) ValueT {
	if value[0] == `{` && value[value.len - 1] == `}` {
		return load(value.all_after_first('{').before('}'))
	} else if value[0] == `[` && value[value.len - 1] == `]` {
		return split_array(value).map(|it| deserialize(it.trim_space()))
	} else if value[0] == `'` && value[value.len - 1] == `'` {
		return value#[1..value.len - 1]
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

pub fn save(fp string, data map[string]ValueT) ! {
	mut file := os.create(fp)!
	defer { file.close() }
	for key, value in data {
		file.write_string('${key} = ${value.serialize()}')!
	}
}

fn load_new(code string) []string {
	mut scanner := textscanner.new(code)
	mut ch := ` `
	mut tokens := []string{}
	mut buf := strings.new_builder(0)
	whitespace := '\r\t\f\n '

	for {
		ch = scanner.next()

		if ch == `/` && scanner.peek() == `/` {
			for {
				ch = scanner.next()
				if ch == `\n` || ch == -1 {
					break
				}
			}
		} else if ch == `\n` && buf.len > 0 {
			tokens << buf.str()
			buf = strings.new_builder(0)
		}
	}
}

fn tokenize(code string) []string {
	// Bad comments no parsing!
	mut cleaned_code := strings.new_builder(code.len)
	for line in code.split_into_lines() {
		if line.trim_space() == '' || line.trim_space().starts_with('//') {
			continue
		}
		cleaned_code.write_string(line)
	}

	// Tokenize
	mut scanner := textscanner.new(code)
	mut ch := ` `
	mut tokens := []string{}
	mut buf := strings.new_builder(0)
	whitespace := '\r\t\f\n '

	for {
		ch = scanner.next()

		if ch == `/` && scanner.peek() == `/` {
			for {
				ch = scanner.next()
				if ch == `\n` || ch == -1 {
					break
				}
			}
		} else if ch == `\n` && buf.len > 0 {
			tokens << buf.str()
			buf = strings.new_builder(0)
		} else if whitespace.contains_u8(ch) {
		} else if ch == `=` {
			// Flush
			if buf.len > 0 {
				tokens << buf.str()
				buf = strings.new_builder(0)
			}

			tokens << ch.str()
		} else if ch == `'` {
			// Flush
			if buf.len > 0 {
				tokens << buf.str()
				buf = strings.new_builder(0)
			}

			for {
				ch = scanner.next()
				if ch == `'` && scanner.peek_back() != `\\` {
					break
				}
				buf.write_rune(ch)
			}

			tokens << "'${buf.str()}'"
			buf = strings.new_builder(0)
		} else if ch == `[` {
			// Flush
			if buf.len > 0 {
				tokens << buf.str()
				buf = strings.new_builder(0)
			}

			mut depth := 1
			mut in_string := false
			buf.write_rune(`[`)
			for {
				ch = scanner.next()
				// Comments
				if ch == `/` && scanner.peek() == `/` {
					for {
						ch = scanner.next()
						if ch == `\n` || ch == -1 {
							break
						}
					}
				}
				// Strings
				else if ch == `'` && scanner.peek_back() != `\\` {
					in_string = !in_string
				}
				// Nested arrays
				else if ch == `[` {
					depth++
				} else if ch == `]` {
					depth--
					if depth == 0 {
						break
					}
				}

				buf.write_rune(ch)
			}
			buf.write_rune(`]`)

			tokens << buf.str()
			buf = strings.new_builder(0)
		} else if ch == `{` {
			// Flush
			if buf.len > 0 {
				tokens << buf.str()
				buf = strings.new_builder(0)
			}

			mut depth := 1
			mut in_string := false
			buf.write_rune(`{`)
			for {
				ch = scanner.next()
				// Comments
				if ch == `/` && scanner.peek() == `/` {
					for {
						ch = scanner.next()
						if ch == `\n` || ch == -1 {
							break
						}
					}
				}
				// Strings
				else if ch == `'` && scanner.peek_back() != `\\` {
					in_string = !in_string
				}
				// Nested arrays
				else if ch == `{` {
					depth++
				} else if ch == `}` {
					depth--
					if depth == 0 {
						break
					}
				}

				buf.write_rune(ch)
			}
			buf.write_rune(`}`)

			tokens << buf.str()
			buf = strings.new_builder(0)
		} else if ch == -1 {
			break
		} else {
			buf.write_rune(ch)
		}
	}

	return tokens
}

struct Statement {
pub:
	key string
	value string
}

@[inline] fn parse(code string) []Statement {
	mut statements := []Statement{}
	tokens := tokenize(code)

	for token in tokens { println(token) }

	for i in 0 .. tokens.len {
		if tokens[i] == '=' {
			statements << Statement{tokens[i - 1], tokens[i + 1]}
		}
	}

	return statements
}

@[inline] pub fn load(code string) map[string]ValueT {
	mut table := map[string]ValueT{}
	for statement in parse(code) {
		table[statement.key] = deserialize(statement.value)
	}
	return table
}

@[inline] pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)
}
