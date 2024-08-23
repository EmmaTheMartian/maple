module maple

fn test_load() {
	// data := tokenize(os.read_file('example.map') or {
	// 	println(err)
	// 	panic('Failed to load example.map')
	// })
	data := load_file('example.map') or {
		println(err)
		panic('Failed to load example.map')
	}
	println(data)
}
