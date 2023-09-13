
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

