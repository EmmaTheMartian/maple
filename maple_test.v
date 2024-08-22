module maple

fn test_load() {
	data := load_file('example.map') or {
		println(err)
		panic('Failed to load example.map')
	}
	println(data)
}
