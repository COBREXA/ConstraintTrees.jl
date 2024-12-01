
# Copyright (c) 2023-2024, University of Luxembourg                        #src
# Copyright (c) 2023, Heinrich-Heine University Duesseldorf                #src
#                                                                          #src
# Licensed under the Apache License, Version 2.0 (the "License");          #src
# you may not use this file except in compliance with the License.         #src
# You may obtain a copy of the License at                                  #src
#                                                                          #src
#     http://www.apache.org/licenses/LICENSE-2.0                           #src
#                                                                          #src
# Unless required by applicable law or agreed to in writing, software      #src
# distributed under the License is distributed on an "AS IS" BASIS,        #src
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #src
# See the License for the specific language governing permissions and      #src
# limitations under the License.                                           #src

# # Example: Mixed integer optimization (MILP)
#
# This example demonstrates the extension of `ConstraintTree` bounds structures
# to accommodate new kinds of problems. In particular, we create a new kind of
# `Bound` that is restricting the value to be a full integer, and then solve a
# geometric problem with that.

# ## Creating a custom bound
#
# All bounds contained in constraints are subtypes of the abstract
# [`ConstraintTrees.Bound`](@ref). These include
# [`ConstraintTrees.EqualTo`](@ref) and [`ConstraintTrees.Between`](@ref), but
# the types can be extended as necessary, given the final rewriting of the
# constraint system to JuMP can handle the new bounds.
#
# Let's make a small "marker" bound for something that needs to be integer-ish,
# between 2 integers:

import ConstraintTrees as C

mutable struct IntegerFromTo <: C.Bound
    from::Int
    to::Int
end

# We can now write e.g. a bound on the number on a thrown six-sided die as
# follows:

IntegerFromTo(1, 6)

# ...and include this bound in constraints and variables:

dice_system = C.variables(keys = [:first_dice, :second_dice], bounds = IntegerFromTo(1, 6))

# Now the main thing that is left is to be able to translate this bound to JuMP
# for solving. We can slightly generalize our constraint-translation system
# from the previous examples for this purpose, by separating out the functions
# that create the constraints:

import JuMP

function jump_constraint(m, x, v::C.Value, b::C.EqualTo)
    JuMP.@constraint(m, C.substitute(v, x) == b.equal_to)
end

function jump_constraint(m, x, v::C.Value, b::C.Between)
    isinf(b.lower) || JuMP.@constraint(m, C.substitute(v, x) >= b.lower)
    isinf(b.upper) || JuMP.@constraint(m, C.substitute(v, x) <= b.upper)
end

# JuMP does not support direct integrality constraints, so we need to make a
# small digression with a slack variable:
function jump_constraint(m, x, v::C.Value, b::IntegerFromTo)
    var = JuMP.@variable(m, integer = true)
    JuMP.@constraint(m, var >= b.from)
    JuMP.@constraint(m, var <= b.to)
    JuMP.@constraint(m, C.substitute(v, x) == var)
end

function milp_optimized_vars(cs::C.ConstraintTree, objective::C.Value, optimizer)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
    JuMP.@objective(model, JuMP.MAX_SENSE, C.substitute(objective, x))
    C.traverse(cs) do c
        isnothing(c.bound) || jump_constraint(model, x, c.value, c.bound)
    end
    JuMP.set_silent(model)
    JuMP.optimize!(model)
    JuMP.value.(model[:x])
end

# Let's try to solve a tiny system with the dice first. What's the best value
# we can throw if the dice are thrown at least 1.5 points apart?

dice_system *=
    :points_distance^C.Constraint(
        dice_system.first_dice.value - dice_system.second_dice.value,
        C.Between(1.5, Inf),
    )

# For solving, we use GLPK (it has MILP capabilities).
import GLPK
dices_thrown = C.substitute_values(
    dice_system,
    milp_optimized_vars(
        dice_system,
        dice_system.first_dice.value + dice_system.second_dice.value,
        GLPK.Optimizer,
    ),
)

@test isapprox(dices_thrown.first_dice, 6.0) #src
@test isapprox(dices_thrown.second_dice, 4.0) #src

# ## A note on pretty-printing of custom extensions
#
# By default, pretty-printing via [`pretty`](@ref ConstraintTrees.pretty)
# attempts to fall back to `Base.show` for any value which has no explicit
# overload of `pretty`. In particular, the bounds in our MILP system are
# formatted as follows:

C.pretty(dice_system)

# To provide a prettier rendering, it is sufficient to provide a matching
# overload of [`pretty`](@ref ConstraintTrees.pretty):

function C.pretty(io::IO, x::IntegerFromTo; style_args...)
    print(io, " ∈ {$(x.from) … $(x.to)}")
end

C.pretty(dice_system)

# ## A more realistic example with geometry
#
# Let's find the size of the smallest right-angled triangle with integer side
# sizes (aka a Pythagorean triple).

vars = C.variables(keys = [:a, :b, :c], bounds = IntegerFromTo(1, 100))

# For simpliclty, we make a shortcut for "values" in all variables:
v = C.map(C.value, vars, C.Value)

# With that shortcut, the constraint tree constructs quite easily:
triangle_system =
    :sides^vars *
    :circumference^C.Constraint(sum(values(v))) *
    :a_less_than_b^C.Constraint(v.b - v.a, (0, Inf)) *
    :b_less_than_c^C.Constraint(v.c - v.b, (0, Inf)) *
    :right_angled^C.Constraint(C.squared(v.a) + C.squared(v.b) - C.squared(v.c), 0.0)

C.pretty(triangle_system, format_variable = i -> ["", "A", "B", "C"][i+1])

# We will need a solver that supports both quadratic and integer optimization:
import SCIP
triangle_sides =
    C.substitute_values(
        triangle_system,
        milp_optimized_vars(
            triangle_system,
            -triangle_system.circumference.value,
            SCIP.Optimizer,
        ),
    ).sides

@test isapprox(triangle_sides.a, 3.0) #src
@test isapprox(triangle_sides.b, 4.0) #src
@test isapprox(triangle_sides.c, 5.0) #src
