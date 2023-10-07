
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
# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct ValueTree
    elems::SortedDict{Symbol,Union{Float64,ValueTree}}
    ValueTree(x::Constraint, vars::AbstractVector{Float64}) = substitute(value(x), vars)
    ValueTree(x::ConstraintTree, vars::AbstractVector{Float64}) = new(
        SortedDict{Symbol,SolutionTreeElem}(keys(x) .=> ValueTree.(values(x), Ref(vars))),
    )
end

"""
$(TYPEDEF)

A shortcut for type of contents in a [`ValueTree`](@ref).
"""
const SolutionTreeElem = Union{Float64,ValueTree}

"""
$(TYPEDSIGNATURES)

Get the elements dictionary out of the [`ValueTree`](@ref).

The use is similar as with the overload for [`ConstraintTree`](@ref).
"""
elems(x::ValueTree) = getfield(x, :elems)

function Base.getproperty(x::ValueTree, sym::Symbol)
    elems(x)[sym]
end

Base.keys(x::ValueTree) = keys(elems(x))

Base.values(x::ValueTree) = values(elems(x))

Base.length(x::ValueTree) = length(elems(x))

Base.iterate(x::ValueTree) = iterate(elems(x))
Base.iterate(x::ValueTree, st) = iterate(elems(x), st)

Base.eltype(x::ValueTree) = eltype(elems(x))

Base.propertynames(x::ValueTree) = keys(elems(x))

Base.getindex(x::ValueTree, sym::Symbol) = getindex(elems(x), sym)
