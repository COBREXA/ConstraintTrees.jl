
"""
$(TYPEDEF)

A structure similar to [`ConstraintTree`](@ref), but only holds the resolved
values of each constraint. As with [`ConstraintTree`](@ref), use record dot
notation and [`elems`](@ref) to browse the solution structure.

Use [`SolutionTree`](@ref) to construct the [`SolutionTree`](@ref) out of a
[`ConstraintTree`](@ref) and a vector of variable values.

To construct a `SolutionTree`, combine a [`ConstraintTree`](@ref) (or generally
any [`ConstraintTreeElem`](@ref) with a vector of variable assignments
(typically representing a constrained problem solution) using the overloaded
2-parameter[`SolutionTree`](@ref) constructor. The result will contain a tree
of constraint values w.r.t. the given variable assignment (or just a single
number in case the input was only a single constraint).

# Example
```
cs = ConstraintTree(...)
vals = [1.0, 2.0, 4.0]
SolutionTree(cs, vals)
```
# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct SolutionTree
    elems::SortedDict{Symbol,Union{Float64,SolutionTree}} = SortedDict()

    SolutionTree(x...) = new(x...)
    SolutionTree(x::Constraint, vars::AbstractVector{Float64}) =
        value_product(x.value, vars)
    SolutionTree(x::QConstraint, vars::AbstractVector{Float64}) =
        qvalue_product(x.qvalue, vars)
    SolutionTree(x::ConstraintTree, vars::AbstractVector{Float64}) = new(
        SortedDict{Symbol,SolutionTreeElem}(
            keys(x) .=> SolutionTree.(values(x), Ref(vars)),
        ),
    )
end

"""
$(TYPEDEF)

A shortcut for type of contents in a [`SolutionTree`](@ref).
"""
const SolutionTreeElem = Union{Float64,SolutionTree}

"""
$(TYPEDSIGNATURES)

Get the elements dictionary out of the [`SolutionTree`](@ref).

The use is similar as with the overload for [`ConstraintTree`](@ref).
"""
elems(x::SolutionTree) = getfield(x, :elems)

function Base.getproperty(x::SolutionTree, sym::Symbol)
    elems(x)[sym]
end

Base.isempty(x::SolutionTree) = isempty(elems(x))

Base.length(x::SolutionTree) = length(elems(x))

Base.keys(x::SolutionTree) = keys(elems(x))

Base.haskey(x::SolutionTree, sym::Symbol) = haskey(elems(x), sym)

Base.values(x::SolutionTree) = values(elems(x))

Base.iterate(x::SolutionTree) = iterate(elems(x))
Base.iterate(x::SolutionTree, st) = iterate(elems(x), st)

Base.eltype(x::SolutionTree) = eltype(elems(x))

Base.propertynames(x::SolutionTree) = keys(elems(x))

Base.hasproperty(x::SolutionTree, sym::Symbol) = haskey(x, sym)

Base.getindex(x::SolutionTree, sym::Symbol) = getindex(elems(x), sym)
