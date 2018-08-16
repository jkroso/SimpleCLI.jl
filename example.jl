#!/usr/bin/env julia --color=yes
@require "." @CLI

"Prints a message x times"
@CLI (times::Integer, messages::String...; color::Symbol=:red, newline::Bool)

times < 0 && throw(ArgumentError("cannot repeat negative times"))
for i in 1:times
  printstyled(join(messages, ' '), color=color)
  newline && println()
end
