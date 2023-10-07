
"""
$(TYPEDEF)

A structure similar to [`ConstraintTree`](@ref), but only holds the resolved
values of each constraint. As with [`ConstraintTree`](@ref), use record dot
notation and [`elems`](@ref) to browse the solution structure.

Use [`ValueTree`](@ref) to construct the [`ValueTree`](@ref) out of a
[`ConstraintTree`](@ref) and a vector of variable values.

To construct a `ValueTree`, combine a [`ConstraintTree`](@ref) (or generally
any [`ConstraintTreeElem`](@ref) with a vector of variable assignments
(typically representing a constrained problem solution) using the overloaded
2-parameter[`ValueTree`](@ref) constructor. The result will contain a tree
of constraint values w.r.t. the given variable assignment (or just a single
number in case the input was only a single constraint).

# Example
```
cs = ConstraintTree(...)
vals = [1.0, 2.0, 4.0]
ValueTree(cs, vals)
```
"""
const ValueTree = Tree{Float64}

const ValueTreeElem = Union{Float64,ValueTree}

ValueTree(x::ConstraintTree, vars::Vector{Float64}) =
    ValueTree(keys(x) .=> ValueTree.(values(x), Ref(vars)))
ValueTree(x::Constraint, vars::Vector{Float64}) = substitute(value(x), vars)
