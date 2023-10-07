"""
$(README)
"""
module ConstraintTrees

using DocStringExtensions

include("linear_value.jl")
include("quadratic_value.jl")
include("bound.jl")
include("constraint.jl")
include("constraint_tree.jl")
include("value_tree.jl")

end # module ConstraintTrees
