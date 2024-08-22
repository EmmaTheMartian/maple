module maple

import os
import strings
import strings.textscanner
import regex
import datatypes

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

	s := builder.str()
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

const maple_regex = '.*\\s*=\\s*((\\d+(\\.\\d+)?)|(\'((.*)?)\')|(true)|(false)|(\\[.*\\])|(\\{.*\\}))'

fn parse(code string) []string {
	// Bad comments no parsing!
	mut cleaned_code := strings.new_builder(code.len)
	for line in code.split_into_lines() {
		if line.trim_space() == '' || line.trim_space().starts_with('//') {
			continue
		}
		cleaned_code.write_string(line)
	}

	// Character-by-character parse
	mut scanner := textscanner.new(code)
	mut ch := ` `
	mut statements := []string{}
	mut brace_stack := datatypes.Stack{}
	mut in_string := false
	for {
		ch = scanner.next()

		if ch == `=` {

		} else if ch == -1 {
			break
		}
	}

	// Compile regex
	mut re := regex.new()
	re.compile_opt(maple_regex) or {
		println(err)
		panic('Failed to compile regex. This should not happen.')
	}

	// Parse the newly cleaned code
	return re.find_all_str(cleaned_code.str())
}

pub fn load(code string) map[string]ValueT {
	mut table := map[string]ValueT{}
	for token in parse(code) {
		println(token)
		table[token.before('=').trim_space()] = deserialize(token.all_after_first('=').trim_space())
	}
	return table
}

@[inline] pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)
}
