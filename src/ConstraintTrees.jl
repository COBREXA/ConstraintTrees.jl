"""
Package `ConstraintTrees.jl` provides a simple data structure
[`ConstraintTree`](@ref) for organizing the contents of linear and quadratic
constrained optimization problems. As a main goal, it abstracts over the
distinction between constraints and variables, allowing much tidier
representation for many kinds of complex constraint systems.

The primary purpose of `ConstraintTrees.jl` is to work with
[COBREXA.jl](https://github.com/LCSB-BioCore/COBREXA.jl); but the package is
otherwise completely independent, lightweight, dependency-free and
usecase-agnostic. Generally, it is intended to be used with
[JuMP](https://github.com/jump-dev/JuMP.jl) and the documentation uses JuMP for
demonstrations, but any other solver framework will do just as well.

The package is structured as follows:

- There is no representation for variables in the model; instead, values depend
  on anonymous numbered variables, and, if suitable, special named values may
  "implicitly" serve as representations for variables. This assumption erases
  the distinction between a "simple" variable and a complex derived linear
  combination, allowing more freedom in model construction.
- Variables may be combined into [`LinearValue`](@ref)s and
  [`QuadraticValue`](@ref)s, which are affine combinations and quadratic-affine
  combinations (respecitively) of values of some selected variables.
- Values may be bounded to an interval or exact value using a
  [`Constraint`](@ref)
- A collection of named [`Constraint`](@ref)s is called a
  [`ConstraintTree`](@ref); it behaves mostly as a specialized `Symbol`-keyed
  dictionary.
- [`ConstraintTree`](@ref)s can be very easily organized into subdirectories,
  combined and made independent on each other using operators `^`, `*`, and `+`
  -- this forms the basis of the "tidy" algebra of constraints.
- A variable assignment, which is typically the "solution" for a given
  constraint tree, can be combined with a [`ConstraintTree`](@ref) to create a
  [`ValueTree`](@ref), which enables browsing of the optimization results in
  the very same structure as the input [`ConstraintTree`](@ref).

You can follow the examples in documentation and the docstrings of package
contents for more details.
"""
module ConstraintTrees

using DocStringExtensions

include("linear_value.jl")
include("quadratic_value.jl")
include("bound.jl")
include("constraint.jl")
include("tree.jl")
include("constraint_tree.jl")
include("value_tree.jl")
include("pretty.jl")

end # module ConstraintTrees
