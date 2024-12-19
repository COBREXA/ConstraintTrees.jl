
# Copyright (c) 2023-2024, University of Luxembourg
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
  on anonymous numbered variables that are mostly hidden in normal use.  This
  assumption erases the distinction between a "simple" variable and a complex
  derived linear combination, allowing more freedom in model construction. If
  required, named values may still "implicitly" serve as representations for
  variables.
- Variables may be combined into [`LinearValue`](@ref)s and
  [`QuadraticValue`](@ref)s, which are affine combinations and quadratic-affine
  combinations (respectively) of values of some selected variables.
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
  "value tree" via [`substitute_values`](@ref). Value trees enable browsing of
  the optimization results in the very same structure as the input
  [`ConstraintTree`](@ref).

You can follow the examples in documentation and the docstrings of package
contents for more details.
"""
module ConstraintTrees

using DocStringExtensions

include("value.jl")
include("linear_value.jl")
include("quadratic_value.jl")
include("bound.jl")
include("constraint.jl")
include("tree.jl")
include("constraint_tree.jl")
include("pretty.jl")

# API definition
#
# ConstraintTrees export only the main used type names (they generally don't
# collide and `using ConstraintTrees` would help a lot with neater formatting
# of data print-outs)

export Value, LinearValue, QuadraticValue
export Bound, Between, EqualTo
export Constraint, Tree, ConstraintTree

# For sufficiently new Julias, we also include the `public` markers for
# non-exported but used names.
if VERSION >= v"1.11"
    include("public_api.jl")
end

end # module ConstraintTrees
