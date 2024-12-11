module main

import emmathemartian.maple
import os
import cli

fn main() {
	mut app := cli.Command{
		name: 'maple'
		description: 'CLI frontend to interact with maple files'
	}

	app.add_command(cli.Command{
		name: 'get'
		description: 'Get a given value from a maple file'
		usage: 'FILE KEY'
		required_args: 2
		execute: fn (cmd cli.Command) ! {
			data := maple.load_file(cmd.args[0]) or {
				eprintln('Failed to load file ${cmd.args[0]} (error: ${err})')
				exit(1)
			}
			println(data.get(cmd.args[1]).serialize(indent_str: '\t'))
		}
	})

	// TODO: Maintain comments and whitespace
	app.add_command(cli.Command{
		name: 'set'
		description: 'Set a given value in a maple file. Note that this will remove additional whitespace and comments.'
		usage: 'FILE KEY VALUE'
		required_args: 3
		execute: fn (cmd cli.Command) ! {
			mut data := maple.load_file(cmd.args[0]) or {
				eprintln('Failed to load file ${cmd.args[0]} (error: ${err})')
				exit(1)
			}
			mut decon := maple.DeserializationContext{}
			data[cmd.args[1]] = maple.deserialize(cmd.args[2], mut decon)
			maple.save_file(cmd.args[0], data) or {
				eprintln('Failed to save file ${cmd.args[0]}')
				exit(1)
			}
		}
	})

	app.add_command(cli.Command{
		name: 'keys'
		description: 'List all keys in a maple file'
		usage: 'FILE'
		required_args: 1
		execute: fn (cmd cli.Command) ! {
			data := maple.load_file(cmd.args[0]) or {
				eprintln('Failed to load file ${cmd.args[0]} (error: ${err})')
				exit(1)
			}
			for key, _ in data {
				println(key)
			}
		}
	})

	app.add_command(cli.Command{
		name: 'values'
		description: 'List all values in a maple file'
		usage: 'FILE'
		required_args: 1
		execute: fn (cmd cli.Command) ! {
			data := maple.load_file(cmd.args[0]) or {
				eprintln('Failed to load file ${cmd.args[0]} (error: ${err})')
				exit(1)
			}
			for _, val in data {
				println(val)
			}
		}
	})

	app.parse(os.args)
}
