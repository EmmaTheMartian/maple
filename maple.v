module maple

import strings
import os

// A sum type to represent any possible value in Maple
pub type ValueT = string | int | f32 | bool | map[string]ValueT | []ValueT

@[inline]
pub fn (value ValueT) to_str() string {
	return value as string
}

@[inline]
pub fn (value ValueT) to_int() int {
	return value as int
}

@[inline]
pub fn (value ValueT) to_f32() f32 {
	return value as f32
}

@[inline]
pub fn (value ValueT) to_bool() bool {
	return value as bool
}

@[inline]
pub fn (value ValueT) to_map() map[string]ValueT {
	return value as map[string]ValueT
}

@[inline]
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

// str converts the value to a parsable string
@[inline]
pub fn (value ValueT) str() string {
	return value.serialize()
}

@[params]
pub struct SerializeOptions {
pub:
	indents    int
	indent_str string = '\t'
}

// serialize converts a value to a parsable string.
pub fn (value ValueT) serialize(opts SerializeOptions) string {
	match value {
		string {
			return '\'${value}\''
		}
		int {
			return value.str()
		}
		f32 {
			return value.str()
		}
		bool {
			return value.str()
		}
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
	}
}

enum TokenKind {
	error
	eof
	id
	str    // ".*" or '.*'
	true   // true
	false  // false
	int    // [0-9]+
	float  // [0-9]+\.[0-9]+
	equals // =
	comma  // ,
	oparen // (
	cparen // )
	obrack // [
	cbrack // ]
	obrace // {
	cbrace // }
}

struct Token {
pub mut:
	kind TokenKind
	line int
	col  int
	pos  int
	len  int
}

@[direct_array_access; inline]
fn (tok Token) text(lexer &Lexer) string {
	return (*lexer.text)[tok.pos..tok.pos + tok.len]
}

struct Lexer {
pub:
	text &string
pub mut:
	line  int = 1
	col   int = 1
	start int
	pos   int
}

@[direct_array_access]
fn (mut lexer Lexer) skip_whitespace() {
	for {
		mut ch := (*lexer.text)[lexer.pos]
		if ' \t\r\f'.contains_u8(ch) {
			lexer.pos++
			lexer.col++
		} else if ch == `\n` {
			lexer.pos++
			lexer.col = 1
			lexer.line++
		} else if ch == `/` && (*lexer.text)[lexer.pos] == `/` {
			for ch != `\n` {
				ch = (*lexer.text)[lexer.pos]
				lexer.pos++
			}
			lexer.col = 1
			lexer.line++
		} else {
			return
		}
	}
}

@[direct_array_access]
fn (mut lexer Lexer) next() !Token {
	if lexer.pos >= lexer.text.len {
		return Token{
			kind: .eof
			line: lexer.line
			col:  lexer.col
			pos:  lexer.text.len - 1
			len:  0
		}
	}

	lexer.skip_whitespace()

	lexer.start = lexer.pos

	mut ch := (*lexer.text)[lexer.pos]
	mut kind := TokenKind.error
	lexer.pos++
	lexer.col++

	sym := match ch {
		// vfmt off
		`=` { TokenKind.equals }
		`,` { .comma }
		`(` { .oparen }
		`)` { .cparen }
		`[` { .obrack }
		`]` { .cbrack }
		`{` { .obrace }
		`}` { .cbrace }
		// vfmt on
		else { .error }
	}
	if sym != .error {
		return Token{sym, lexer.line, lexer.col, lexer.start, lexer.pos - lexer.start}
	}

	if ch == `\0` {
		return Token{
			kind: .eof
			line: lexer.line
			col:  lexer.col
			pos:  lexer.text.len - 1
			len:  0
		}
	} else if ch.is_letter() || ch == `_` {
		kind = .id
		lexer.pos++
		lexer.col++
		ch = (*lexer.text)[lexer.pos]
		for ch.is_alnum() || ch == `_` {
			lexer.pos++
			lexer.col++
			ch = (*lexer.text)[lexer.pos]
		}
	} else if ch == `"` || ch == `'` {
		kind = .str
		s := ch
		ch = (*lexer.text)[lexer.pos]
		lexer.pos++
		lexer.col++
		if ch != s {
			for ch != s {
				lexer.pos++
				lexer.col++
				ch = (*lexer.text)[lexer.pos]
				if ch == `\\` {
					lexer.pos++
					lexer.col++
					ch = (*lexer.text)[lexer.pos]
				}
			}
			// eat the closing quote
			lexer.pos++
			lexer.col++
		}
	} else if ch.is_digit() || ch == `-` {
		kind = .int
		lexer.pos++
		lexer.col++
		ch = (*lexer.text)[lexer.pos]
		for ch.is_digit() || ch == `_` {
			lexer.pos++
			lexer.col++
			ch = (*lexer.text)[lexer.pos]
		}
		if ch == `.` {
			kind = .float
			lexer.pos++
			lexer.col++
			ch = (*lexer.text)[lexer.pos]
			for ch.is_digit() || ch == `_` {
				lexer.pos++
				lexer.col++
				ch = (*lexer.text)[lexer.pos]
			}
		}
	} else {
		return error('unexpected character: `${ch.ascii_str()}` (${ch}) at ${lexer.line}:${lexer.col}')
	}

	mut tok := Token{kind, lexer.line, lexer.col, lexer.start, lexer.pos - lexer.start}

	if tok.kind == .id {
		tok.kind = match (*lexer.text)[tok.pos..tok.pos + tok.len] {
			'true' { .true }
			'false' { .false }
			else { tok.kind }
		}
	}

	return tok
}

struct Parser {
pub mut:
	lexer Lexer
	cur   Token
	next  Token
}

fn (mut parser Parser) advance() ! {
	parser.cur = parser.next
	parser.next = parser.lexer.next()!
}

fn (mut parser Parser) accept(kind TokenKind) !bool {
	if parser.next.kind == kind {
		parser.advance()!
		return true
	}
	return false
}

fn (mut parser Parser) expect(kind TokenKind) ! {
	if parser.next.kind != kind {
		return error('expected token of kind ${kind} but got ${parser.next.kind}: \'${parser.next.text(parser.lexer)}\' at ${parser.next.line}:${parser.next.col}')
	}
	parser.advance()!
}

fn (mut parser Parser) parse_value() !ValueT {
	if parser.accept(.str)! {
		return parser.cur.text(parser.lexer).substr_ni(1, -1)
	} else if parser.accept(.int)! {
		return parser.cur.text(parser.lexer).replace('_', '').int()
	} else if parser.accept(.float)! {
		return parser.cur.text(parser.lexer).replace('_', '').f32()
	} else if parser.accept(.true)! {
		return true
	} else if parser.accept(.false)! {
		return false
	} else if parser.accept(.obrack)! {
		mut l := []ValueT{}
		for !parser.accept(.cbrack)! {
			if parser.accept(.eof)! {
				return error('reached eof before closing bracket (`]`)')
			}
			l << parser.parse_value()!
			parser.accept(.comma)!
		}
		return l
	} else if parser.accept(.obrace)! {
		mut m := map[string]ValueT{}
		for !parser.accept(.cbrace)! {
			if parser.accept(.eof)! {
				return error('reached eof before closing brace (`}`)')
			}
			parser.expect(.id)!
			key := parser.cur.text(parser.lexer)
			parser.expect(.equals)!
			m[key] = parser.parse_value()!
			parser.accept(.comma)!
		}
		return m
	}
	return error('failed to parse value')
}

fn (mut parser Parser) parse_doc() !map[string]ValueT {
	mut m := map[string]ValueT{}
	for !parser.accept(.eof)! {
		parser.expect(.id)!
		key := parser.cur.text(parser.lexer)
		parser.expect(.equals)!
		m[key] = parser.parse_value()!
		parser.accept(.comma)!
	}
	return m
}

fn Parser.new(text &string) Parser {
	return Parser{
		lexer: Lexer{
			text: unsafe { text }
		}
	}
}

pub fn deserialize(text string) !ValueT {
	mut parser := Parser.new(text)
	parser.advance()!
	return parser.parse_value()
}

// Deserialize text to a map[string]ValueT
pub fn load(text string) !map[string]ValueT {
	mut parser := Parser.new(text)
	parser.advance()!
	return parser.parse_doc()
}

// Load a map[string]ValueT from a file
@[inline]
pub fn load_file(fp string) !map[string]ValueT {
	return load(os.read_file(fp)!)!
}

// Serialize data to a string
pub fn save(data map[string]ValueT) string {
	// We set an initial buffer of 1024 here because it will prevent smaller configs
	// from needing to grow_len so often.
	mut string_builder := strings.new_builder(1024)
	for key, value in data {
		string_builder.write_string('${key} = ${value.serialize()}\n')
	}
	return string_builder.str()
}

// Save a map[string]ValueT to a file
@[inline]
pub fn save_file(fp string, data map[string]ValueT) ! {
	mut file := os.create(fp)!
	defer { file.close() }
	file.write_string(save(data))!
}
