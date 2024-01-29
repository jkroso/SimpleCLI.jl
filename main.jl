@require "github.com/jkroso/Prospects.jl" assoc

const kw_arg = r"^(-{1,2})(\w+)(?:=(\w+))?"

macro main(tuple)
  cmd = parse_command(Expr(:call, :main, tuple.args...))
  name = esc(gensym(:cmd))
  quote
    Base.@__doc__ $name = $cmd
    push!($name.flags, help)
    mapping = parse_ARGS(Main.ARGS, $name)
    if haskey(mapping, help)
      print_help($cmd, Base.@doc($name))
      exit()
    end
    for param in vcat($name.positionals, $name.flags)
      value = if haskey(mapping, param)
        mapping[param]
      elseif datatype(param) == Bool
        false
      else
        @assert !ismissing(default_value(param)) " please provide a value for $(name(param))"
        default_value(param)
      end
      value = parse_value(param, value)
      $(esc(:eval))(Expr(:(=), name(param), QuoteNode(value)))
    end
  end
end

abstract type Parameter end

struct Single <: Parameter
  name::Symbol
  DT::DataType
  default::Union{Any,Missing}
end

struct Spread <: Parameter
  param::Single
end

const help = Single(:help, Bool, false)

struct Command{name}
  positionals::Vector{Parameter}
  flags::Vector{Parameter}
end

name(::Command{t}) where t = t

macro command(name, block)
  quote
    Base.@__doc__ c = $(parse_command(name))
    if !isempty(Main.ARGS) && Symbol(Main.ARGS[1]) == name(c)
      mapping = parse_ARGS(Main.ARGS[2:end], c)
      for param in vcat(c.positionals, c.flags)
        value = if haskey(mapping, param)
          mapping[param]
        elseif datatype(param) == Bool
          false
        else
          @assert !ismissing(default_value(param)) " please provide a value for $(name(param))"
          default_value(param)
        end
        value = parse_value(param, value)
        $(esc(:eval))(Expr(:(=), name(param), QuoteNode(value)))
      end
      $(esc(block))
      exit()
    end
  end
end

parse_command(title) = begin
  name, params... = title.args
  if !isempty(params) && Meta.isexpr(params[1], :parameters)
    :(Command{$(QuoteNode(name))}($(parse_params(params[2:end])), $(parse_params(params[1].args))))
  else
    :(Command{$(QuoteNode(name))}($(parse_params(params)), []))
  end
end

parse_params(params) = :([$(map(parse_param, params)...)])
parse_param(p) = begin
  if Meta.isexpr(p, :kw) || Meta.isexpr(p, :(=))
    :(assoc($(parse_param(p.args[1])), :default, $(esc(p.args[2]))))
  elseif Meta.isexpr(p, :(::))
    :(Single($(QuoteNode(p.args[1])), $(esc(p.args[2])), missing))
  elseif Meta.isexpr(p, :...)
    :(Spread($(parse_param(p.args[1]))))
  else
    error("Unknown parameter format $p")
  end
end

parse_ARGS(ARGS::Vector, cmd::Command) = begin
  mappings = Dict{Parameter,Any}()
  positionals = 0
  i = 1
  while i <= length(ARGS)
    arg = ARGS[i]
    if occursin(kw_arg, arg)
      dashes, argname, value = match(kw_arg, arg).captures
      # handle compact flags e.g -dp 3000
      if length(dashes) == 1
        ARGS = vcat(ARGS[1:i-1],
                    map(s->"-$s", split(argname, "")),
                    value == nothing ? [] : [value],
                    ARGS[i+1:end])
        arg = ARGS[i]
        dashes, argname, value = match(kw_arg, arg).captures
        flags = filter(f->startswith(String(name(f)), argname), cmd.flags)
      else
        flags = filter(f->name(f) == Symbol(argname), cmd.flags)
      end
      @assert !isempty(flags) "Invalid keyword argument $arg"
      @assert length(flags) == 1 "$arg is ambiguous. Use $(join(map(name, flags), ", ", ", or ")) instead"
      param = flags[1]
      if expects_value(param)
        mappings[param] = value == nothing ? ARGS[i+=1] : value
      else
        mappings[param] = true
      end
    elseif cmd.positionals[positionals + 1] isa Spread
      push!(get!(mappings, cmd.positionals[positionals + 1], []), arg)
    else
      mappings[cmd.positionals[positionals += 1]] = arg
    end
    i += 1
  end
  mappings
end

expects_value(p::Parameter) = datatype(p) != Bool

parse_value(p::Parameter, value::Any) = value
parse_value(s::Spread, value::Vector) = map(a->parse_value(s.param, a), value)
parse_value(p::Single, value::AbstractString) =
  if     p.DT == Integer parse(Int, value)
  elseif p.DT <: Number parse(p.DT, value)
  elseif p.DT <: AbstractString value
  else   p.DT(value)
  end

name(s::Single) = s.name
name(s::Spread) = name(s.param)
datatype(s::Single) = s.DT
datatype(s::Spread) = datatype(s.param)

default_value(p::Spread) = Vector{datatype(p)}()
default_value(p::Single) =
  if ismissing(p.default) p.DT == Bool ? false : p.default
  else p.default
  end

print_help(cmd::Command, doc) = begin
  println(doc)
  println("Positional arguments:")
  for param in cmd.positionals
    print_help(param, false)
  end
  println()
  println("Keyword arguments")
  for param in cmd.flags
    print_help(param, true)
  end
end

print_help(p::Parameter, kw::Bool) = begin
  print("  ")
  kw && print("-$(String(name(p))[1]), --")
  print(name(p), "::", datatype(p))
  p isa Spread && print("...")
  if ismissing(default_value(p))
    println(" (Required)")
  else
    println(" (defaults to $(default_value(p)))")
  end
end
