#!/usr/bin/env julia --color=yes
@use "." @main @command

@command pad(str::String="", len::Integer) begin
  println(repeat(' ', max(0, len-length(str))) * str)
end

"Prints a message x times"
@main (times::Integer, messages::String...; color::Symbol=:red, newline::Bool)

times < 0 && throw(ArgumentError("cannot repeat negative times"))
for i in 1:times
  printstyled(join(messages, ' '), color=color)
  newline && println()
end
