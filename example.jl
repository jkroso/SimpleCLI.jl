#!/usr/bin/env julia --color=yes
@require "." @CLI

"Prints a message x times"
@CLI (message::String, times::Integer=3; color::Symbol=:red, newline::Bool)

times < 0 && throw(ArgumentError("cannot repeat negative times"))
for i in 1:times
  print_with_color(color, message)
  newline && println()
end
