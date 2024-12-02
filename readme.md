# maple

> Literally just a key-value (aka map) based config language. That's it.

Yes, there are loads more of these types of config languages, but I wanted to
make my own because the other options are overkill for my projects.

## What It Looks Like

`maple` is inspired by TOML and can be thought of almost* as a subset of it. The
major differences being:
- `maple` does not use `[these.things]` for maps
- `maple` uses `//` for comments instead of `#`

TL;DR: this:

```maple
key = value;
// allowed values:
// strings have to use single-quotes
my_string = 'Some string'
my_int = 1273
my_float = 12.34
my_bool = false
my_map = {
    my_name = 'Emma'
    more_values = 1273
}
my_array = [
    1,
    'uno',
    3,
    'cuatro'
]
```

What, did you think it was going to be a complex monstrosity?

> For a more comprehensive example, see [`example.maple`](example.maple).

## License

`maple` is dual-licensed under MIT and the Unlicense. Pick whichever you prefer :P
