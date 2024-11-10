
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

# # Quick start
#
# The primary purpose of ConstraintTrees.jl is to make the representation of
# constraint systems neat, and thus make their manipulation easy and
# high-level. In short, the package abstracts the users from keeping track of
# variable and constraint indexes in matrix form, and gives a nice data
# structure that describes the system, while keeping all variable allocation
# and constraint organization completely implicit.
#
# Here we demonstrate the absolutely basic concepts on the "field allocation"
# problem.
#
# ## The problem: Field area allocation
#
# Suppose we have 100 square kilometers of field, 500 kilos of fertilizer and
# 300 kilos of insecticide. We also have a practically infinite supply of wheat
# and barley seeds. If we decide to sow barley, we can make 550🪙 per square
# kilometer of harvest; if we decide to go with wheat instead, we can make
# 350🪙. Unfortunately each square kilometer of wheat requires 6 kilos of
# fertilizer, and 1 kilo of insecticide, whereas each square kilometer of
# barley requires 2 kilos of fertilizer and 4 kilos of insecticide, because
# insects love barley.
#
# How much of our fields should we allocate to wheat and barley to maximize
# our profit?
#
# ## Field area allocation with ConstraintTrees.jl
#
# Let's import the package and start constructing the problem:

import ConstraintTrees as C

# Let's name our system `s`. We first need a few [`variables:`](@ref
# ConstraintTrees.variables)

s = C.variables(keys = [:wheat, :barley])

# With ConstraintTrees.jl, we can (and want to!) label everything very nicely
# -- the constraint trees are essentially directory structures, so one can
# prefix everything with symbols to put it into nice directories, e.g. as such:

:area^s

# To be absolutely realistic, we also want to make sure that all areas are
# non-negative. To demonstrate how to do that nicely from the start, we rather
# re-do the constraints with an appropriate [interval bound](@ref
# ConstraintTrees.Between):

s = :area^C.variables(keys = [:wheat, :barley], bounds = C.Between(0, Inf))

# Constraint trees can be browsed using dot notation, or just like
# dictionaries:

s.area

#

s[:area].barley

# (For convenience in some cases, string indexes are also supported:)

s["area"]["barley"]

# Now let's start rewriting the problem into the constraint-tree-ish
# description. First, we only have 100 square kilometers of area:

total_area = s.area.wheat.value + s.area.barley.value

total_area_constraint = C.Constraint(total_area, (0, 100))

# We can add any kind of [constraint](@ref ConstraintTrees.Constraint) into
# the existing constraint trees by "merging" multiple trees with operator `*`:

s *= :total_area^total_area_constraint

# Now let's add constraints for resources. We can create whole
# [`ConstraintTree`](@ref ConstraintTrees.ConstraintTree) structures like
# dictionaries in place, as follows:

s *=
    :resources^C.ConstraintTree(
        :fertilizer =>
            C.Constraint(s.area.wheat.value * 6 + s.area.barley.value * 2, (0, 500)),
        :insecticide =>
            C.Constraint(s.area.wheat.value * 1 + s.area.barley.value * 4, (0, 300)),
    )

# We can also represent the expected profit as a constraint (although we do not
# need to actually put a constraint bound there):

s *= :profit^C.Constraint(s.area.wheat.value * 350 + s.area.barley.value * 550)

# ## Solving the system with JuMP
#
# We can now take the structure of the constraint tree, translate it to any
# suitable linear optimizer interface, and have it solved. For popular reasons
# we choose [JuMP](https://jump.dev/) with
# [GLPK](https://www.gnu.org/software/glpk/) -- the code is left uncommented
# here as-is; see the other examples for a slightly more detailed explanation:

import JuMP
function optimized_vars(cs::C.ConstraintTree, objective::C.LinearValue, optimizer)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.variable_count(cs)])
    JuMP.@objective(model, JuMP.MAX_SENSE, C.substitute(objective, x))
    C.traverse(cs) do c
        b = c.bound
        if b isa C.EqualTo
            JuMP.@constraint(model, C.substitute(c.value, x) == b.equal_to)
        elseif b isa C.Between
            val = C.substitute(c.value, x)
            isinf(b.lower) || JuMP.@constraint(model, val >= b.lower)
            isinf(b.upper) || JuMP.@constraint(model, val <= b.upper)
        end
    end
    JuMP.optimize!(model)
    JuMP.value.(model[:x])
end

import GLPK
optimal_variable_assignment = optimized_vars(s, s.profit.value, GLPK.Optimizer)

# This gives us the optimized variable values! If we cared to remember what
# they stand for, we might already know how much barley to sow. On the other
# hand, the main point of ConstraintTree.jl is that one should not be forced to
# remember things like variable ordering and indexes, or be forced to manually
# calculate how much money we actually make or how much fertilizer is going to
# be left -- instead, we can simply [feed the variable values back to the
# constraint tree](@ref ConstraintTrees.substitute_values), and get a really
# good overview of all values in our constrained system:

optimal_s = C.substitute_values(s, optimal_variable_assignment)

# ## Browsing the result
#
# `optimal_s` is now like the original constraint tree, just the contents are
# "plain old values" instead of the constraints as above. Thus we can easily
# see our profit:

optimal_s.profit

@test isapprox(optimal_s.profit, 48333.33333333334) #src

# The occupied area for each crop:

optimal_s.area

# The consumed resources:

optimal_s.resources

# ## Increasing the complexity
#
# A crucial property of constraint trees is that the users do not need to care
# about what kind of value they are manipulating -- no matter if something is a
# variable or a derived value, the code that works with it is the same. For
# example, we can use the actual prices for our resources (30🪙 and 110🪙 for a
# kilo of fertilizer and insecticide, respectively) to make a corrected profit:

s *=
    :actual_profit^C.Constraint(
        s.profit.value - 30 * s.resources.fertilizer.value -
        110 * s.resources.insecticide.value,
    )

# Is the result going to change if we optimize for the corrected profit?

realistically_optimal_s =
    C.substitute_values(s, optimized_vars(s, s.actual_profit.value, GLPK.Optimizer))

#

realistically_optimal_s.area

# ## Combining constraint systems: Let's have a factory!
#
# The second crucial property of constraint trees is the ability to easily
# combine different constraint systems into one. Let's pretend we also somehow
# obtained a food factory that produces malty sweet bread and wheaty
# weizen-style beer, with various extra consumptions of water and heat for each
# of the products. For simplicity, let's just create the corresponding
# constraint system (`f` as a factory) here:

f = :products^C.variables(keys = [:bread, :weizen], bounds = C.Between(0, Inf))
f *= :profit^C.Constraint(25 * f.products.weizen.value + 35 * f.products.bread.value)

# We can make the constraint systems more complex by adding additional
# variables. To make sure the variables do not "conflict", one must use the `+`
# operator. While constraint systems combined with `*` always share variables,
# constraint systems combined with `+` are independent.
f += :materials^C.variables(keys = [:wheat, :barley], bounds = C.Between(0, Inf))

# How much resources are consumed by each product, with a limit on each:

f *=
    :resources^C.ConstraintTree(
        :heat => C.Constraint(
            5 * f.products.bread.value + 3 * f.products.weizen.value,
            (0, 1000),
        ),
        :water => C.Constraint(
            2 * f.products.bread.value + 10 * f.products.weizen.value,
            (0, 3000),
        ),
    )

# How much raw materials are required for each product:

f *=
    :material_allocation^C.ConstraintTree(
        :wheat => C.Constraint(
            8 * f.products.bread.value + 2 * f.products.weizen.value -
            f.materials.wheat.value,
            0,
        ),
        :barley => C.Constraint(
            0.5 * f.products.bread.value + 10 * f.products.weizen.value -
            f.materials.barley.value,
            0,
        ),
    )

# Having the two systems at hand, we can connect the factory "system" `f` to
# the field "system" `s`, making a compound system `c` as such:

c = :factory^f + :fields^s

#md # !!! warning "Operators for combining constraint trees"
#md #     Always remember to use `+` instead of `*` when combining _independent_ constraint systems. If we use `*`, the variables in both systems will become implicitly shared, which is rarely what one wants in the first place. Use `*` only if adding additional constraints to an existing system. As a rule of thumb, one can remember the boolean interpretation of `*` as "and" and of `+` as "or".
#md #
#md #     On a side note, the operator `^` was chosen mainly to match the algebraic view of the tree combination, and nicely fit into Julia's operator priority structure.

# To actually connect the systems (which now exist as completely independent
# parts of `s`), let's add a transport -- the barley and wheat produced on the
# fields is going to be the only barley and wheat consumed by the factory, thus
# their production and consumption must sum to net zero:

c *= :transport^C.zip(c.fields.area, c.factory.materials) do area, material
    C.Constraint(area.value - material.value, 0)
end

#md # !!! info "High-level constraint tree manipulation"
#md #     There is also a [dedicated example](4-functional-tree-processing.md) with many more useful functions like [`zip`](@ref ConstraintTrees.zip) above.

# Finally, let's see how much money can we make from having the factory
# supported by our fields in total!

optimal_c =
    C.substitute_values(c, optimized_vars(c, c.factory.profit.value, GLPK.Optimizer))

# How much field area did we allocate?

optimal_c.fields.area

# How much of each of the products does the factory make in the end?

optimal_c.factory.products

# How much extra resources is consumed by the factory?

optimal_c.factory.resources

# And what is the factory profit in the end?

optimal_c.factory.profit

@test isapprox(optimal_c.factory.profit, 361.5506329113926) #src
