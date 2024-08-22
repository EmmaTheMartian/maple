# maple

> Literally just a key-value (aka map) based config language. That's it.

Yes, there are loads more of these types of config languages, but I wanted to make my own
because the other options are overkill for my projects.

## What It Looks Like

`maple` is inspired by TOML and can be thought of as a subset of it. The difference being
that `maple` does not use `[these.things]` for maps.

TL;DR: this:

```maple
key = value
```

What, did you think it was going to be a complex monstrosity?

> For an example showing every type, see [`example.map`](example.map).
