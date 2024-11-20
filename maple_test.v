module maple

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
