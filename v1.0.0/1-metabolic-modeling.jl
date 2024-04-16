
# Copyright (c) 2023, University of Luxembourg                             #src
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

# # Example: Metabolic modeling
#
# In this example we demonstrate the use of `ConstraintTree` structure for
# solving the metabolic modeling tasks. At the same time, we show how to export
# the structure to JuMP, and use value trees to find useful information about
# the result.
#
# First, let's import some packages:

import ConstraintTrees as C

# We will need a constraint-based metabolic model; for this test we will use
# the usual "E. Coli core metabolism" model as available from BiGG:

import Downloads: download

download("http://bigg.ucsd.edu/static/models/e_coli_core.xml", "e_coli_core.xml")

import SBML
ecoli = SBML.readSBML("e_coli_core.xml")

# ## Allocating and constraining variables
#
# Let's first build the constrained representation of the problem. First, we
# will need a variable for each of the reactions in the model.

c = C.variables(keys = Symbol.(keys(ecoli.reactions)))

#md # !!! info "Pretty-printing"
#md #     By default, Julia shows relatively long namespace prefixes before all
#md #     identifiers, which clutters the output. You can import individual
#md #     names form `ConstraintTrees` package to improve the pretty-printing,
#md #     using e.g.:
#md #     `import ConstraintTrees: Constraint, Tree, LinearValue`.

@test length(C.elems(c)) == length(ecoli.reactions) #src

# The above operation returns a [`ConstraintTree`](@ref
# ConstraintTrees.ConstraintTree). You can browse these as a dictionary:
c[:R_PFK]

# ...or much more conveniently using the record dot syntax as properties:
c.R_PFK

# The individual [`LinearValue`](@ref ConstraintTrees.LinearValue)s in
# constraints behave like sparse vectors that refer to variables: The first
# field represents the referenced variable indexes, and the second field
# represents the coefficients. Compared to the sparse vectors, information
# about the total number of variables is not stored explicitly.

# Operator `^` is used to name individual constraints and directories in the
# hierarchy. Let us name our constraints as "fluxes" (which is a common name in
# metabolic modeling) and explore the result:

c = :fluxes^c

@test collect(keys(c)) == [:fluxes] #src
@test issetequal(collect(keys(c.fluxes)), sort(Symbol.(collect(keys(ecoli.reactions))))) #src

# We can see that there is now only a single "top-level directory" in the
# constraint system, which can be explored with the dot access again:
c.fluxes.R_PFK

# Indexing via values is again possible via the usual bracket notation, and can
# be freely combined with the dot notation:
c[:fluxes][:R_PFK]

@test c[:fluxes].R_PFK === c.fluxes[:R_PFK] #src

# ## Adding single-variable constraints

# Each element in the constraint tree consists of a linear combination of the
# variables, which can be freely used to construct (and constraint) new linear
# combinations of variables. As the simplest use, we can constraint the
# variables (using [`Constraint`](@ref ConstraintTrees.Constraint)s) to their
# valid bounds as defined by the model:
rxn_constraints =
    let rxn_bounds = Symbol.(keys(ecoli.reactions)) .=> zip(SBML.flux_bounds(ecoli)...)
        C.ConstraintTree(
            r => C.Constraint(value = c.fluxes[r].value, bound = (lb, ub)) for
            (r, ((lb, _), (ub, _))) in rxn_bounds # SBML units are ignored for simplicity
        )
    end

# Note that in the example we use a simplified `Dict`-like construction of the
# `ConstraintTree`. You might equivalently write the code as a product (using
# `prod()`) of constraints that are individually labeled using the `^`
# operator, but the direct dictionary construction is faster because it skips
# many intermediate steps, and looks much more like idiomatic Julia code.

# To combine the constraint trees, we can make a nice directory for the
# constraints and add them to the tree using operator `*`. Making "products" of
# constraint trees combines the trees in a way that they _share_ their
# variables. In particular, using the values from `c.fluxes` in the constraints
# within `rxn_constraints` here will constraint precisely the same variables
# (and thus values) as the ones in the original system.
c = c * :constraints^rxn_constraints

# Our model representation now contains 2 "directories":
collect(keys(c))

@test 2 == length((keys(c))) #src

# ## Value and constraint arithmetics

# Values may be combined additively and multiplied by real constants; which
# allows us to easily create more complex linear combination of any values
# already occurring in the model:
3 * c.fluxes.R_PFK.value - c.fluxes.R_ACALD.value / 2

# For simplicity, you can also scale whole constraints, but it is impossible to
# add them together because the meaning of the bounds would get broken:
(3 * c.fluxes.R_PFK, -c.fluxes.R_ACALD / 2)

# To process constraints in bulk, you may use `C.value` for easier access to
# values when making new constraints:
sum(C.value.(values(c.fluxes)))

# ### Affine values
#
# To simplify various modeling goals (mainly calculation of various kinds of
# "distances"), the values support inclusion of an affine element -- the
# variable with index 0 is assumed to be the "affine unit", and its assigned
# value is fixed at `1.0`.

# To demonstrate, let's make a small system with 2 variables.
system = C.variables(keys = [:x, :y])

# To add an affine element to a `LinearValue`, simply add it as a `Real`
# number, as in the linear transformations below:
system =
    :original_coords^system *
    :transformed_coords^C.ConstraintTree(
        :xt => C.Constraint(1 + system.x.value + 4 + system.y.value),
        :yt => C.Constraint(0.1 * (3 - system.y.value)),
    )

# ## Adding combined constraints

# Metabolic modeling relies on the fact that the total rates of any metabolite
# getting created and consumed by the reaction equals to zero (which
# corresponds to conservation of mass). We can now add corresponding
# "stoichiometric" network constraints by following the reactants and products
# in the SBML structure:
stoi_constraints = C.ConstraintTree(
    Symbol(m) => C.Constraint(
        value = -sum(
            (
                sr.stoichiometry * c.fluxes[Symbol(rid)].value for
                (rid, r) in ecoli.reactions for sr in r.reactants if sr.species == m
            ),
            init = zero(C.LinearValue), # sometimes the sums are empty
        ) + sum(
            (
                sr.stoichiometry * c.fluxes[Symbol(rid)].value for
                (rid, r) in ecoli.reactions for sr in r.products if sr.species == m
            ),
            init = zero(C.LinearValue),
        ),
        bound = 0.0,
    ) for m in keys(ecoli.species)
);

# Let's have a closer look at one of the constraints:

stoi_constraints.M_acald_c

# Again, we can label the stoichiometry properly and add it to the bigger model
# representation:
c = c * :stoichiometry^stoi_constraints

# ## Saving the objective
#
# Constraint based models typically optimize a certain linear formula.
# Constraint trees do not support setting objectives (they are not
# constraints), but we can save the objective as a harmless unconstrained
# "constraint" that can be used later to refer to the objective more easily.
# We can save that information into the constraint system immediately:
c *=
    :objective^C.Constraint(
        sum(
            c.fluxes[Symbol(rid)].value * coeff for
            (rid, coeff) in (keys(ecoli.reactions) .=> SBML.flux_objective(ecoli)) if
            coeff != 0.0
        ),
    )

# ## Constrained system solutions and value trees
#
# To aid exploration of variable assignments in the constraint trees, we can
# convert them to *value trees*. These have the very same structure as
# constraint trees, but carry only the "solved" constraint values instead of
# full constraints.
#
# Let's demonstrate this quickly on the example of `system` with affine
# variables from above. First, let's assume that someone solved the system (in
# some way) and produced a solution of variables as follows:
solution = [1.0, 5.0] # corresponds to :x and :y in order given in `variables`

# A value tree for this solution is constructed in a straightforward manner:
st = C.substitute_values(system, solution)

# We can now check the values of the original coordinates
st.original_coords

@test isapprox(st.original_coords.x, 1.0) #src
@test isapprox(st.original_coords.y, 5.0) #src

# The other constraints automatically get their values that correspond to the
# overall variable assignment:
st.transformed_coords

@test isapprox(st.transformed_coords.xt, 11.0) #src
@test isapprox(st.transformed_coords.yt, -0.2) #src

# ## Solving the constraint system using JuMP
#
# We can make a small function that throws our model into JuMP, optimizes it,
# and gives us back a variable assignment vector. This vector can then be used
# to determine and browse the values of constraints and variables using a
# `Float64`-valued tree.
import JuMP
function optimized_vars(cs::C.ConstraintTree, objective::C.LinearValue, optimizer)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
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

# With this in hand, we can use an external linear problem solver to find the
# optimum of the constrained system:
import GLPK
optimal_variable_assignment = optimized_vars(c, c.objective.value, GLPK.Optimizer)

# To explore the solution more easily, we can make a tree with values that
# correspond to ones in our constraint tree:
result = C.substitute_values(c, optimal_variable_assignment)

result.fluxes.R_BIOMASS_Ecoli_core_w_GAM

#

result.fluxes.R_PFK

# Sometimes it is unnecessary to recover the values for all constraints, so we
# are better off selecting just the right subtree:
C.substitute_values(c.fluxes, optimal_variable_assignment)

#

C.substitute_values(c.objective, optimal_variable_assignment)

# We'll save the `result` for future use at the end of this example:

result_single_organism = result

# ## Combining and extending constraint systems
#
# Constraint trees can be extended with new variables from another constraint
# trees using the `+` operator. Contrary to the `*` operator, adding the
# constraint trees does _not_ share the variables between operands, and the
# resulting constraint tree will basically contain two disconnected trees that
# solve independently. The user is expected to create additional constraints to
# connect the independent parts.
#
# Here, we demonstrate this by creating a community of two slightly different
# E. Coli species: First, we disable functionality of a different reaction in
# each of the models to create a diverse group of differently handicapped
# organisms:
c =
    :community^(
        :species1^(c * :handicap^C.Constraint(c.fluxes.R_PFK.value, 0)) +
        :species2^(c * :handicap^C.Constraint(c.fluxes.R_ACALD.value, 0))
    )

# We can create additional variables that represent total community intake of
# oxygen, and total community production of biomass:
c += :exchanges^C.variables(keys = [:oxygen, :biomass], bounds = [(-10.0, 10.0), nothing])

# These can be constrained so that the total influx (or outflux) of each of the
# registered metabolites is in fact equal to total consumption or production by
# each of the species:
c *=
    :exchange_constraints^C.ConstraintTree(
        :oxygen => C.Constraint(
            value = c.exchanges.oxygen.value - c.community.species1.fluxes.R_EX_o2_e.value -
                    c.community.species2.fluxes.R_EX_o2_e.value,
            bound = 0.0,
        ),
        :biomass => C.Constraint(
            value = c.exchanges.biomass.value -
                    c.community.species1.fluxes.R_BIOMASS_Ecoli_core_w_GAM.value -
                    c.community.species2.fluxes.R_BIOMASS_Ecoli_core_w_GAM.value,
            bound = 0.0,
        ),
    )

# Let's see how much biomass are the two species capable of producing together:
result =
    C.substitute_values(c, optimized_vars(c, c.exchanges.biomass.value, GLPK.Optimizer))
result.exchanges

# Finally, we can iterate over all species in the small community and see how
# much biomass was actually contributed by each:
Dict(k => v.fluxes.R_BIOMASS_Ecoli_core_w_GAM for (k, v) in result.community)

# ## Modifying constraint systems in-place
#
# Constraint trees can be modified in-place in a way that allows you to easily
# change small values in the trees without reconstructing them from the ground
# up.
#
# Although in-place modification is extremely convenient and looks much easier
# than rebuilding the tree, it may be very detrimental to the robustness and
# efficiency of the programs, for several reasons:
#
# - changing any data breaks assumptions on anything that was already derived
#   from the data
# - for efficiency, the tree structures are _not copied_ by default if there's
#   no need to do it, and only shared by references; which means that a naive
#   change at a single place of the tree may easily change values also in other
#   parts of any trees, including completely different trees
# - the "convenient way" of making sure that the above problem never happens is
#   to deep-copy the whole tree structure, which is typically quite detrimental
#   to memory use and program efficiency
#
#md # !!! danger "Rules of thumb for safe use of in-place modification"
#md #     Only use the in-place modifications if:
#md #     - there is code that explicitly makes sure there is no false sharing via references, e.g. using a deep copy
#md #     - the in-place modifications are the last thing happening to the constraint tree before it is used by the solver
#md #     - the in-place modification code is not a part of a re-usable library
#
# Now, if you are completely sure that ignoring the robustness guidelines will
# help your code, you can do the in-place tree modifications quite easily using
# both dot-access and array-index syntax.

# You can thus, e.g., set a single bound:
c.exchanges.oxygen.bound = C.Between(-20.0, 20.0)

# ...or rebuild a whole constraint (using a tuple shortcut for
# [`ConstraintTrees.Between`](@ref)):
c.exchanges.biomass = C.Constraint(c.exchanges.biomass.value, (-20, 20))

# ...or even add new constraints, here using the index syntax for demonstration:
c[:exchanges][:production_is_zero] = C.Constraint(c.exchanges.biomass.value, 0)

# ...or remove some constraints (this erases the constraint that was added just
# above):
delete!(c.exchanges, :production_is_zero)

# In the end, the flux optimization yields an expectably different result:
result_with_more_oxygen =
    C.substitute_values(c, optimized_vars(c, c.exchanges.biomass.value, GLPK.Optimizer))
result.exchanges

@test result_with_more_oxygen.exchanges.oxygen < -19.0 #src

# ## Seeing the differences between the results
#
# ConstraintTrees.jl defines its own version of `zip` function that can apply a
# function to the contents of several trees, "zipping" them over the same keys
# in the structure. This is vaguely similar but otherwise not related to the
# `zip` from Julia base (similarly, ConstraintTrees.jl have their own specific
# `map`).
#
# In practice, this allows you to create combined trees with various nice
# properties very quickly. For example, you can find how much the values have
# changed between our two communities:

C.zip((x, y) -> y - x, result, result_with_more_oxygen, Float64)

# The result is again a `Tree`, with the contained type specified by the last
# argument (`Float64` in this case). We can explore it right away as the other
# result trees. Also, it is possible to call this kind of function using the
# Julia `do` notation, making the syntax a bit neater:

difference = C.zip(result, result_with_more_oxygen, Float64) do x, y
    y - x
end

# Exploring the difference works as expected:

difference.community.species1.fluxes

# For convenience in special cases, `zip` is also overloaded for 3 arguments.
# We can, for a completely artificial example, check if the absolute flux
# change was bigger in the first or in the second organism in the community
# when compared to the original single-organism flux (which we luckily saved
# above):

changes = C.zip(
    result.community.species1,
    result.community.species2,
    result_single_organism,
    Bool,
) do s1, s2, orig
    abs(s1 - orig) > abs(s2 - orig)
end

changes.fluxes

# More high-level functions like `zip` are described in [an example on
# functional tree processing](4-functional-tree-processing.md).
