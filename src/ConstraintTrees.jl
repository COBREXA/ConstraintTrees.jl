module ConstraintTrees

import DataStructures: SortedDict

using DocStringExtensions
using SparseArrays

#
# Values
#

"""
$(TYPEDEF)

A representation of a "value" in a linear constrained optimization problem. The
value is a linear combination of several variables.

Values can be combined additively and multiplied by real-number constants.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Value
    """
    Indexes of the variables used by the value. The indexes are always sorted
    in increasing order.
    """
    idxs::Vector{Int}
    "Coefficients of the variables as used by the value"
    weights::Vector{Float64}
end

Base.:*(a::Real, b::Value) = b * a
Base.:*(a::Value, b::Real) = Value(idxs = a.idxs, weights = b .* a.weights)
Base.:-(a::Value, b::Value) = a + (-1 * b)
Base.:-(a::Value) = -1 * a
Base.:/(a::Value, b::Real) = Value(idxs = a.idxs, weights = a.weights ./ b)

function Base.:+(a::Value, b::Value)
    r_idxs = Int[]
    r_weights = Float64[]
    ai = 1
    ae = length(a.idxs)
    bi = 1
    be = length(b.idxs)
    while ai <= ae && bi <= be
        if a.idxs[ai] < b.idxs[bi]
            push!(r_idxs, a.idxs[ai])
            push!(r_weights, a.weights[ai])
            ai += 1
        elseif a.idxs[ai] > b.idxs[bi]
            push!(r_idxs, b.idxs[bi])
            push!(r_weights, b.weights[bi])
            bi += 1
        else # a.idxs[ai] == b.idxs[bi] -- merge case
            push!(r_idxs, a.idxs[ai])
            push!(r_weights, a.weights[ai] + b.weights[bi])
            ai += 1
            bi += 1
        end
    end
    while ai <= ae
        push!(r_idxs, a.idxs[ai])
        push!(r_weights, a.weights[ai])
        ai += 1
    end
    while bi <= be
        push!(r_idxs, b.idxs[bi])
        push!(r_weights, b.weights[bi])
        bi += 1
    end
    Value(idxs = r_idxs, weights = r_weights)
end

"""
$(TYPEDSIGNATURES)

Shortcut for making a dot-product between a value and anything indexable by the
value indexes.
"""
value_product(x::Value, y) = x.weights' * y[x.idxs]

"""
$(TYPEDSIGNATURES)

Shortcut for making a [`Value`](@ref) out of `SparseVector`.
"""
Value(x::SparseVector{Float64}) =
    let (idxs, weights) = findnz(x)
        Value(; idxs, weights)
    end

#
# Constraints
#

"""
$(TYPEDEF)

Shortcut for possible bounds: either no bound is present (`nothing`), or a
single number is interpreted as an exact equality bound, or a tuple of 2 values
is interpreted as an interval bound.
"""
const Bound = Union{Nothing,Float64,IntervalBound}

"""
$(TYPEDEF)

Convenience shortcut for "interval" bound; consisting of lower and upper bound
value.
"""
const IntervalBound = Tuple{Float64, Float64}

"""
$(TYPEDEF)

A representation of a single constraint that limits the [`Value`](@ref) by a
specific [`Bound`](@ref).

Constraints may be multiplied by real-number constants.

Constraints without a bound (`nothing` in the `bound` field) are possible;
these have no impact on the optimization problem but the associated `value`
becomes easily accessible for inspection and building other constraints.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Constraint
    "A [`Value`](@ref) that describes what the constraint constraints."
    value::Value
    "A bound that the value must satisfy."
    bound::Bound = nothing
end

Base.:*(a::Real, b::Constraint) = b * a
Base.:*(a::Constraint, b::Real) = Constraint(
    value = a.value * b,
    bound = a.bound isa Float64 ? a.bound * b :
            a.bound isa Tuple{Float64,Float64} ? a.bound .* b : nothing,
)
Base.:/(a::Constraint, b::Real) = Constraint(
    value = a.value / b,
    bound = a.bound isa Float64 ? a.bound / b :
            a.bound isa Tuple{Float64,Float64} ? a.bound ./ b : nothing,
)

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the value from the constraint that can be used
for broadcasting (as opposed to the dot-field access).
"""
value(x::Constraint) = x.value

#
# Constraint trees
#

"""
$(TYPEDEF)

A hierarchical tree of many constraints that together describe a constrained
linear system. The tree may recursively contain other trees in a directory-like
structure.

Members of the constraint tree are accessible via the record dot syntax as
properties; e.g. a constraint labeled with `:abc` in a constraint tree `t` may
be accessed as `t.abc` and as `t[:abc]`, and can be found while iterating
through `elems(t)`.

# Constructing the constraint trees

Use operator `^` to put a name on a [`Constraint`](@ref) to convert it into a
single element [`ConstraintTree`](@ref):

```julia
x = :myConstraint ^ Constraint(Value(...), 1.0)
dir = :myConstraintDir ^ x

dir.myConstraintDir.myConstraint.bound   # returns 1.0
```

Use operator `*` to glue two constraint trees together while *sharing* the
variable indexes specified by the contained [`Value`](@ref)s.

```julia
myConstraints = :constraint1 ^ Constraint(...) * :constraint2 ^ Constraint(...)
```

Use operator `+` to glue two constraint trees together *without sharing* of any
variables. The operation will renumber the variables in the trees so that the
sets of variable indexes used by either tree are completely disjunct, and then
glue the trees together as with `*`:

```julia
twoIndependentModels = myModel + otherModel
```

Because of the renumbering, you can not easily use constraints and values from
the values *before* the addition in the constraint tree that is the result of
the addition. There is no check against that; the resulting
[`ConstraintTree`](@ref) will be valid, but will probably describe a different
optimization problem than you intended.

As a rule of thumb, avoid necessary parentheses in expressions that work with
the constraint trees: While `t1 * t2 + t3` might work just as intended, `t1 *
(t2 + t3)` is almost certainly wrong because the variables in `t1` that are
supposed to connect to variables in either of `t2` and `t3` will not connect
properly because of renumbering of both `t2` and `t3`. If you need to construct
a tree like that, do the addition first, and construct the `t1` after that,
based on the result of the addition.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct ConstraintTree
    "Sorted dictionary of elements of the constraint tree."
    elems::SortedDict{Symbol,Union{Constraint,ConstraintTree}}
end

"""
$(TYPEDEF)

A shortcut for elements of the [`ConstraintTree`](@ref).
"""
const ConstraintTreeElem = Union{Constraint,ConstraintTree}

"""
$(TYPEDSIGNATURES)

Create a properly typed [`ConstraintTree`](@ref) out of anything that can be
used to construct the inner dictionary.

# Example
```julia
make_constraint_tree(:a => some_constraint, :b => another_constraint)
make_constraint_tree(c for c=constraints if !isnothing(c.bound))
```
"""
make_constraint_tree(x...) =
    ConstraintTree(elems = SortedDict{Symbol,ConstraintTreeElem}(x...))

"""
$(TYPEDSIGNATURES)

Get the elements dictionary out of the [`ConstraintTree`](@ref). This is useful
for getting an iterable container for working with many constraints at once.

Also, because of the overload of `getproperty` for `ConstraintTree`, this
serves as a simpler way to get the elements without an explicit use of
`getfield`.
"""
elems(x::ConstraintTree) = getfield(x, :elems)

function Base.getproperty(x::ConstraintTree, sym::Symbol)
    elems(x)[sym]
end

Base.propertynames(x::ConstraintTree) = keys(elems(x))

Base.getindex(x::ConstraintTree, sym::Symbol) = getindex(elems(x), sym)

#
# Algebraic construction
#

Base.:^(pfx::Symbol, x::ConstraintTreeElem) = ConstraintTree(elems = SortedDict(pfx => x))

function Base.:+(a::ConstraintTree, b::ConstraintTree)
    offset = var_count(a)
    a * incr_var_idxs(b, offset)
end

function Base.:*(a_orig::ConstraintTree, b_orig::ConstraintTree)
    # TODO this might be much better inplace, but the copy luckily ain't substantial
    a = copy(elems(a_orig))
    b = elems(b_orig)

    for (k, v) in b
        if haskey(a, k)
            a[k] = a[k] * v
        else
            a[k] = v
        end
    end

    ConstraintTree(elems = a)
end

function Base.:*(a::ConstraintTree, b::Constraint)
    error("Unable to merge a constraint directory with a constraint.")
end

function Base.:*(a::Constraint, b::ConstraintTree)
    error("Unable to merge a constraint with a constraint directory.")
end

function Base.:*(a::Constraint, b::Constraint)
    error("Unable to merge two constraints.")
end

#
# Solution trees
#

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

Base.propertynames(x::SolutionTree) = keys(elems(x))

Base.getindex(x::SolutionTree, sym::Symbol) = getindex(elems(x), sym)

"""
$(TYPEDSIGNATURES)

Convert a single constraint and a vector of variable assignments (typically
representing a constrained problem solution) to the value of the constraint
w.r.t. the given variable assignment.
"""
solution_tree(x::Constraint, vars::AbstractVector{Float64}) = value_product(x.value, vars)

"""
$(TYPEDSIGNATURES)

Convert a [`ConstraintTree`](@ref) and a vector of variable assignments (typically
representing a constrained problem solution) to a [`SolutionTree`](@ref) of
constraint values w.r.t. the given variable assignment.
"""
solution_tree(x::ConstraintTree, vars::AbstractVector{Float64}) = SolutionTree(
    elems = SortedDict{Symbol,SolutionTreeElem}(
        keys(elems(x)) .=> solution_tree.(values(elems(x)), Ref(ov)),
    ),
)

end # module ConstraintTrees
