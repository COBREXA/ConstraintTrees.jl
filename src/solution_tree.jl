
"""
$(TYPEDEF)

A structure similar to [`ConstraintTree`](@ref), but only holds the resolved
values of each constraint. As with [`ConstraintTree`](@ref), use record dot
notation and [`elems`](@ref) to browse the solution structure.

Use [`solution_tree`](@ref) to construct the [`SolutionTree`](@ref) out of a
[`ConstraintTree`](@ref) and a vector of variable values.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct SolutionTree
    elems::SortedDict{Symbol,Union{Float64,SolutionTree}}
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

Base.keys(x::SolutionTree) = keys(elems(x))

Base.values(x::SolutionTree) = values(elems(x))

Base.length(x::SolutionTree) = length(elems(x))

Base.iterate(x::SolutionTree) = iterate(elems(x))
Base.iterate(x::SolutionTree, st) = iterate(elems(x), st)

Base.eltype(x::SolutionTree) = eltype(elems(x))

Base.propertynames(x::SolutionTree) = keys(elems(x))

Base.getindex(x::SolutionTree, sym::Symbol) = getindex(elems(x), sym)

"""
$(TYPEDSIGNATURES)

Combine a [`ConstraintTree`](@ref) (or generally any
[`ConstraintTreeElem`](@ref) with a vector of variable assignments (typically
representing a constrained problem solution) to a [`SolutionTree`](@ref) of
constraint values w.r.t. the given variable assignment.
"""
function solution_tree end

solution_tree(x::Constraint, vars::AbstractVector{Float64}) = value_product(x.value, vars)
solution_tree(x::QConstraint, vars::AbstractVector{Float64}) =
    qvalue_product(x.qvalue, vars)
solution_tree(x::ConstraintTree, vars::AbstractVector{Float64}) = SolutionTree(
    elems = SortedDict{Symbol,SolutionTreeElem}(
        keys(x) .=> solution_tree.(values(x), Ref(vars)),
    ),
)
