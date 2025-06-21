# SimpleCLI.jl

Provides simple syntax for defining the parameters a CLI script takes. Inspired by [Fire.jl](//github.com/ylxdzsw/Fire.jl). You will need [Kip.jl](//github.com/jkroso/Kip.jl) installed.

## Example

```julia
#!/usr/bin/env julia --color=yes
@require "github.com/jkroso/SimpleCLI.jl" @cli

"Prints a message x times"
@cli main(message::String, times::Integer=3; color::Symbol=:red, newline::Bool=true) = begin
  times < 0 && throw(ArgumentError("cannot repeat negative times"))
  for i in 1:times
    print_with_color(color, message)
    newline && println()
  end
end
```

Now this script will be callable in all kinds of typical CLI ways:

```sh
repeat hello
repeat hello 3
repeat hello --color red
repeat hello --color=red -n
repeat hello -nc red
repeat hello -nc=red
repeat -nc red hello
```

All of these commands produce the same result which is:

```
hello
hello
hello
```

And it will have a `--help` command defined which prints the `@doc` string followed by a desciption of the arguments it takes:

```
$ repeat -h
Prints a message x times

Positional arguments:
  message::String (Required)
  times::Integer (defaults to 3)

Keyword arguments
  -c, --color::Symbol (defaults to red)
  -n, --newline::Bool (defaults to false)
  -h, --help::Bool (defaults to false)
```
