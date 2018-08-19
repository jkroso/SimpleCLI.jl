@require "github.com/MikeInnes/MacroTools.jl" striplines
@require "github.com/jkroso/Prospects.jl" assoc

const kw_arg = r"^(-{1,2})(\w+)(?:=(\w+))?"

macro CLI(tuple)
  tuple = striplines(tuple)
  cli = if Meta.isexpr(tuple, :block)
    parse_CLI(:(a($(tuple.args[1]); $(tuple.args[2]))).args[2:end])
  else
    parse_CLI(tuple.args)
  end
  quote
    Base.@__doc__ cli = $cli
    mapping = parse_ARGS(Main.ARGS, cli)
    if haskey(mapping, help)
      print_help(cli, Base.@doc(cli))
      exit()
    end
    for param in vcat(cli.positionals, cli.flags)
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

struct CLI
  positionals::Vector{Parameter}
  flags::Vector{Parameter}
  CLI(p,f) = new(p, vcat(f, help))
end

parse_CLI(params) = begin
  if Meta.isexpr(params[1], :parameters)
    :(CLI($(parse_params(params[2:end])), $(parse_params(params[1].args))))
  else
    :(CLI($(parse_params(params)), []))
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

parse_ARGS(ARGS::Vector, cli::CLI) = begin
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
        flags = filter(f->startswith(String(name(f)), argname), cli.flags)
      else
        flags = filter(f->name(f) == Symbol(argname), cli.flags)
      end
      @assert !isempty(flags) "Invalid keyword argument $arg"
      @assert length(flags) == 1 "$arg is ambiguous. Use $(join(map(name, flags), ", ", ", or ")) instead"
      param = flags[1]
      if expects_value(param)
        mappings[param] = value == nothing ? ARGS[i+=1] : value
      else
        mappings[param] = true
      end
    elseif cli.positionals[positionals + 1] isa Spread
      push!(get!(mappings, cli.positionals[positionals + 1], []), arg)
    else
      mappings[cli.positionals[positionals += 1]] = arg
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

print_help(cli::CLI, doc) = begin
  println(doc)
  println("Positional arguments:")
  for param in cli.positionals
    print_help(param, false)
  end
  println()
  println("Keyword arguments")
  for param in cli.flags
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
