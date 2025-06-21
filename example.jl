#!/usr/bin/env julia --color=yes
@use "." @cli

"Adds padding to a string to make it `len` characters long"
@cli pad(str::String="", len::Integer) = begin
  println(repeat(' ', max(0, len-length(str))) * str)
end

"Prints a message x times"
@cli main(times::Integer, messages::String...; color::Symbol=:red, newline::Bool) = begin
  times < 0 && throw(ArgumentError("cannot repeat negative times"))
  for i in 1:times
    printstyled(join(messages, ' '), color=color)
    newline && println()
  end
end
