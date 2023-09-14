
# # Example: Metabolic modeling
#
# In this example we demonstrate the use of `ConstraintTree` structure for
# solving the metabolic modeling tasks. At the same time, we show how to export
# the structure to JuMP, and use `SolutionTree` to find useful information
# about the result.
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

c = C.allocate_variables(keys = Symbol.(keys(ecoli.reactions)))

@test length(C.elems(c)) == length(ecoli.reactions) #src

# The above operation returns a `ConstraintTree`. You can browse these as a
# dictionary:
C.elems(c)

# ...or much more conveniently using the record dot syntax as properties:
c.R_PFK

# The individual `Value`s in constraint behave like sparse vectors that refer
# to variables: The first field represents the referenced variable indexes, and
# the second field represents the coefficients. Compared to the sparse vectors,
# information about the total number of variables is not stored explicitly.

# Operator `^` is used to name individual constraints and directories in the
# hierarchy. Let us name our constraints as "fluxes" (which is a common name in
# metabolic modeling) and explore the result:

c = :fluxes^c;

# We can see that there is now only a single "top-level directory" in the
# constraint system:
collect(keys(C.elems(c)))

@test collect(keys(c)) == [:fluxes] #src
@test issetequal(collect(keys(c.fluxes)), sort(Symbol.(collect(keys(ecoli.reactions))))) #src

# ...which can be explored with the dot access again:
c.fluxes.R_PFK

# Indexing via values is possible via the usual bracket notation, and can be
# freely combined with the dot notation:
c[:fluxes][:R_PFK]

@test c[:fluxes].R_PFK === c.fluxes[:R_PFK] #src

# ## Adding single-variable constraints

# Each element in the constraint tree consists of a linear combination of the
# variables, which can be freely used to construct (and constraint) new linear
# combinations of variables. As the simplest use, we can constraint the
# variables to their valid bounds as defined by the model:
rxn_constraints =
    let rxn_bounds = Symbol.(keys(ecoli.reactions)) .=> zip(SBML.flux_bounds(ecoli)...)
        C.make_constraint_tree(
            r => C.Constraint(value = c.fluxes[r].value, bound = (lb, ub)) for
            (r, ((lb, _), (ub, _))) in rxn_bounds # SBML units are ignored for simplicity
        )
    end

# To combine the constraint trees, we can make a nice directory for the
# constraints and add them to the tree using operator `*`. Making "products" of
# constraint trees combines the trees in a way that they _share_ their
# variables. In particular, using the values from `c.fluxes` in the constraints
# within `rxn_constraints` here will constraint precisely the same variables
# (and thus values) as the ones in the original system.
c = c * :constraints^rxn_constraints;

# Our model representation now contains 2 "directories":
collect(keys(c))

@test 2 == length((keys(c)))#src

# ## Value and constraint arithmetics

# Values may be combined additively and multiplied by real constants; which
# allows us to easily create more complex linear combination of any values
# already occurring in the model:
3 * c.fluxes.R_PFK.value - c.fluxes.R_ACALD.value / 2

# For simplicity, you can also scale whole constraints, but it is impossible to
# add them together because the meaning of the bounds would get broken:
(3 * c.fluxes.R_PFK, -c.fluxes.R_ACALD / 2)

# To process constraints in bulk, you may use `C.value` for easier access to
# values and making constraints.
sum(C.value.(values(c.fluxes)))

# ## Adding combined constraints

# Metabolic modeling relies on the fact that the total rates of any metabolite
# getting created and consumed by the reaction equals to zero (which
# corresponds to conservation of mass). We can now add corresponding
# "stoichiometric" network constraints by following the reactants and products
# in the SBML structure:
stoi_constraints = C.make_constraint_tree(
    Symbol(m) => C.Constraint(
        value = -sum(
            (
                sr.stoichiometry * c.fluxes[Symbol(rid)].value for
                (rid, r) in ecoli.reactions for sr in r.reactants if sr.species == m
            ),
            init = zero(C.Value), # sometimes the sums are empty
        ) + sum(
            (
                sr.stoichiometry * c.fluxes[Symbol(rid)].value for
                (rid, r) in ecoli.reactions for sr in r.products if sr.species == m
            ),
            init = zero(C.Value),
        ),
        bound = 0.0,
    ) for m in keys(ecoli.species)
);

# Again, we can label the stoichiometry properly and add it to the bigger model
# representation:
c = c * :stoichiometry^stoi_constraints;

# ## Saving the objective
#
# Constraint based models typically optimize a certain linear formula.
# Constraint trees do not support setting objectives (they are not
# constraints), but we can save the objective as a harmless unconstrained
# "constraint" that can be used later to refer to the objective more easily.
# We can save that information into the constraint system immediately:
c *=
    :objective^C.Constraint(
        value = sum(
            c.fluxes[Symbol(rid)].value * coeff for
            (rid, coeff) in (keys(ecoli.reactions) .=> SBML.flux_objective(ecoli)) if
            coeff != 0.0
        ),
    );

# ## Solving the constraint system using JuMP
#
# We can make a small function that throws our model into JuMP, optimizes it,
# and gives us back a variable assignment vector. This vector can then be used
# to determine and browse the values of constraints and variables using
# `SolutionTree`.
import JuMP
function optimized_vars(cs::C.ConstraintTree, objective::C.Value, optimizer)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
    JuMP.@objective(model, JuMP.MAX_SENSE, C.value_product(objective, x))
    function add_constraint(c::C.Constraint)
        if c.bound isa Float64
            JuMP.@constraint(model, C.value_product(c.value, x) == c.bound)
        elseif c.bound isa Tuple{Float64,Float64}
            val = C.value_product(c.value, x)
            isinf(c.bound[1]) || JuMP.@constraint(model, val >= c.bound[1])
            isinf(c.bound[2]) || JuMP.@constraint(model, val <= c.bound[2])
        end
    end
    function add_constraint(c::C.ConstraintTree)
        add_constraint.(values(c))
    end
    add_constraint(cs)
    JuMP.optimize!(model)
    JuMP.value.(model[:x])
end

# With this in hand, we can use an external linear problem solver to find the
# optimum of the constrained system:
import GLPK
optimal_variable_assignment = optimized_vars(c, c.objective.value, GLPK.Optimizer)

# To explore the solution more easily, we can make a solution tree with values
# that correspond to ones in our constraint tree:
result = C.solution_tree(c, optimal_variable_assignment);
result.fluxes.R_BIOMASS_Ecoli_core_w_GAM

#

result.fluxes.R_PFK

#

result.objective

# Sometimes it is unnecessary to recover the values for all constraints, so we are better off selecting just a subtree:
C.elems(C.solution_tree(c.fluxes, optimal_variable_assignment))

#

C.solution_tree(c.objective, optimal_variable_assignment)

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
        :species1^(c * :handicap^C.Constraint(value = c.fluxes.R_PFK.value, bound = 0.0)) +
        :species2^(c * :handicap^C.Constraint(value = c.fluxes.R_ACALD.value, bound = 0.0))
    )

# We can create additional variables that represent total community intake of
# oxygen, and total community production of biomass:
c +=
    :exchanges^C.allocate_variables(
        keys = [:oxygen, :biomass],
        bounds = [(-10.0, 10.0), nothing],
    )

# These can be constrained so that the total influx (or outflux) of each of the
# registered metabolites is in fact equal to total consumption or production by
# each of the species:
c *=
    :exchange_constraints^C.make_constraint_tree(
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
result = C.solution_tree(c, optimized_vars(c, c.exchanges.biomass.value, GLPK.Optimizer));
C.elems(result.exchanges)

# Finally, we can iterate over all species in the small community and see how
# much biomass was actually contributed by each:
[k => v.fluxes.R_BIOMASS_Ecoli_core_w_GAM for (k, v) in result.community]
