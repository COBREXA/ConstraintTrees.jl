
# # Example: Mixed integer optimization (MILP)
#
# This example demonstrates the extension of `ConstraintTree` bounds structures
# to accomodate new kinds of problems. In particular, we create a new kind of
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

dice_system =
    C.variables(keys = [:first_dice, :second_dice], bounds = [IntegerFromTo(1, 6)])

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
# small disgression with a slack variable:
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
    function add_constraint(c::C.Constraint)
        isnothing(c.bound) || jump_constraint(model, x, c.value, c.bound)
    end
    function add_constraint(c::C.ConstraintTree)
        add_constraint.(values(c))
    end
    add_constraint(cs)
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
dices_thrown = C.constraint_values(
    dice_system,
    milp_optimized_vars(
        dice_system,
        dice_system.first_dice.value + dice_system.second_dice.value,
        GLPK.Optimizer,
    ),
)

@test isapprox(dices_thrown.first_dice, 6.0) #src
@test isapprox(dices_thrown.second_dice, 4.0) #src

# ## A more realistic example with geometry
#
# Let's find the size of the smallest right-angled triangle with integer side
# sizes (aka a Pythagorean triple).

vars = C.variables(keys = [:a, :b, :c], bounds = (IntegerFromTo(1, 100),))

# For simpliclty, we make a shortcut for "values" in all variables:
v = C.tree_map(vars, C.value, C.Value)

# With that shortcut, the constraint tree constructs quite easily:
triangle_system =
    :sides^vars *
    :circumference^C.Constraint(sum(values(v))) *
    :a_less_than_b^C.Constraint(v.b - v.a, (0, Inf)) *
    :b_less_than_c^C.Constraint(v.c - v.b, (0, Inf)) *
    :right_angled^C.Constraint(C.squared(v.a) + C.squared(v.b) - C.squared(v.c), 0.0)

# We will need a solver that supports both quadratic and integer optimization:
import SCIP
triangle_sides =
    C.constraint_values(
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
