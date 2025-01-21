module maple

struct User {
pub mut:
	name     string
	password string
	age      u8
	token    u64 @[skip]
	id       u32 @[maple: 'identifier']
}

fn test_string() {
	data := "my_string = 'Hello, World!'"
	assert load(data)!.get('my_string').to_str() == 'Hello, World!'
}

fn test_string_2() {
	data := 'my_string = "Hello, World!"'
	assert load(data)!.get('my_string').to_str() == 'Hello, World!'
}

fn test_int() {
	data := 'value = 1234'
	assert load(data)!.get('value').to_int() == 1234
}

fn test_negative_int() {
	data := 'value = -1234'
	assert load(data)!.get('value').to_int() == -1234
}

fn test_f32() {
	data := 'value = 12.34'
	assert load(data)!.get('value').to_f32() == 12.34
}

fn test_negative_f32() {
	data := 'value = -12.34'
	assert load(data)!.get('value').to_f32() == -12.34
}

fn test_bool() {
	true_data := 'value = true'
	false_data := 'value = false'
	assert load(true_data)!.get('value').to_bool()
	assert !load(false_data)!.get('value').to_bool()
}

fn test_array() {
	data := "my_array = [1, 2, 3, 'a', 'b', 'c']"
	loaded := load(data)!.get('my_array').to_array()
	assert loaded[0].to_int() == 1
	assert loaded[1].to_int() == 2
	assert loaded[2].to_int() == 3
	assert loaded[3].to_str() == 'a'
	assert loaded[4].to_str() == 'b'
	assert loaded[5].to_str() == 'c'
}

fn test_map() {
	data := "my_map = {
		song = 'Old Yellow Bricks'
		artist = 'Arctic Monkeys'
		album = 'Favourite Worst Nightmare'
		track_number = 11
		year = 2007
	}"
	loaded := load(data)!.get('my_map').to_map()
	assert loaded.get('song').to_str() == 'Old Yellow Bricks'
	assert loaded.get('artist').to_str() == 'Arctic Monkeys'
	assert loaded.get('album').to_str() == 'Favourite Worst Nightmare'
	assert loaded.get('track_number').to_int() == 11
	assert loaded.get('year').to_int() == 2007
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

fn test_load_struct() {
	data := load_to_struct[User]('\
		name = "Emma"
		password = "haha lol"
		age = 90384725
		identifier = 1111') or {
			panic(err)
		}
	assert data.name == 'Emma'
	assert data.password == 'haha lol'
	assert data.age == 90384725
	assert data.token == 0
	assert data.id == 1111
}
