
# # Example: Metabolic modeling
#
# In this example we demonstrate the use of `ConstraintTree` structure for
# solving the metabolic modeling tasks. At the same time, we show how to export
# the structure to JuMP, and use `SolutionTree` to find useful information
# about the result.
#
# First, let's import some packages:

import ConstraintTrees as C
import JuMP, SBML

# We will need a constraint-based metabolic model; for this test we will use
# the usual "E. Coli core metabolism" model as available from BiGG:

import Downloads: download

download("http://bigg.ucsd.edu/static/models/e_coli_core.xml", "e_coli_core.xml")

ecoli = SBML.readSBML("e_coli_core.xml")

# Let's first build the constrained representation of the problem. First, we
# will need a variable for each of the reactions in the model:

c = C.allocate_variables(keys = Symbol.(keys(ecoli.reactions)));

@test length(C.elems(c)) == length(ecoli.reactions) #src

# The above operation returns a `ConstraintTree`. You can browse these as a
# dictionary:
C.elems(c)

# ...or much more conveniently using the record dot syntax as properties:
c.R_PFK

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
