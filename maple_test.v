module maple

fn test_string() {
	data := 'my_string = \'Hello, World!\''
	assert load(data)!.get('my_string').to_str() == 'Hello, World!'
}

fn test_array() {
	data := 'my_array = [1, 2, 3, \'a\', \'b\', \'c\']'
	loaded := load(data)!.get('my_array').to_array()
	assert loaded[0].to_int() == 1
	assert loaded[1].to_int() == 2
	assert loaded[2].to_int() == 3
	assert loaded[3].to_str() == 'a'
	assert loaded[4].to_str() == 'b'
	assert loaded[5].to_str() == 'c'
}

fn test_load() {
	data := load_file('example.maple') or {
		println(err)
		panic('Failed to parse or load example.map')
	}
	saved := save(data)
	println('Saved:')
	println(saved)
	unsaved := load(saved) or {
		println(err)
		panic('Failed to parse or load reserialized data from example.map')
	}
	println('Raw Loaded Data:')
	println(data)
	println('Raw->Serialize->Load Loaded Data:')
	println(unsaved)
	assert data.get('playlist_info').get('name').to_str() == '\${Vibes}'
	assert data.get('playlist_info').get('author').to_str() == 'Emma'
	println('Playlist: ${data.get('playlist_info').get('name').to_str()} by ${data.get('playlist_info').get('author').to_str()}')
	assert data == unsaved
	println('Passed: ${data == unsaved}')
}
