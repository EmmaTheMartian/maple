module maple

fn test_string() {
	assert load("my_string = 'Hello, World!'")!.get('my_string').to_str() == 'Hello, World!'
}

fn test_string_2() {
	assert load('my_string = "Hello, World!"')!.get('my_string').to_str() == 'Hello, World!'
}

fn test_int() {
	assert load('value = 1234')!.get('value').to_int() == 1234
}

fn test_big_int() {
	assert load('value = 1_000_000')!.get('value').to_int() == 1_000_000
}

fn test_negative_int() {
	assert load('value = -1234')!.get('value').to_int() == -1234
}

fn test_f32() {
	assert load('value = 12.34')!.get('value').to_f32() == 12.34
}

fn test_negative() {
	assert load('value = -12.34')!.get('value').to_f32() == -12.34
}

fn test_bool() {
	assert load('value = true')!.get('value').to_bool()
	assert !load('value = false')!.get('value').to_bool()
}

fn test_array() {
	loaded := load("my_array = [1, 2, 3, 'a', 'b', 'c']")!.get('my_array').to_array()
	assert loaded[0].to_int() == 1
	assert loaded[1].to_int() == 2
	assert loaded[2].to_int() == 3
	assert loaded[3].to_str() == 'a'
	assert loaded[4].to_str() == 'b'
	assert loaded[5].to_str() == 'c'
}

fn test_map() {
	loaded := load("my_map = {
		song = 'Old Yellow Bricks' // comment
		artist = 'Arctic Monkeys'
		album = 'Favourite Worst Nightmare'
		track_number = 11
		year = 2007
	}")!.get('my_map').to_map()
	assert loaded.get('song').to_str() == 'Old Yellow Bricks'
	assert loaded.get('artist').to_str() == 'Arctic Monkeys'
	assert loaded.get('album').to_str() == 'Favourite Worst Nightmare'
	assert loaded.get('track_number').to_int() == 11
	assert loaded.get('year').to_int() == 2007
}

fn test_load() {
	data := load_file('example.maple') or {
		println(err)
		panic('Failed to parse or load example.maple: ${err}')
	}
	saved := save(data)
	println('Saved:')
	println(saved)
	unsaved := load(saved) or {
		println(err)
		panic('Failed to parse or load reserialized data from example.maple')
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
