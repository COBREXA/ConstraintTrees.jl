
import DataStructures: SortedDict

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
x = :my_constraint ^ Constraint(Value(...), 1.0)
dir = :my_constraint_dir ^ x

dir.my_constraint_dir.my_constraint.bound   # returns 1.0
```

Use operator `*` to glue two constraint trees together while *sharing* the
variable indexes specified by the contained [`Value`](@ref)s.

```julia
my_constraints = :constraint1 ^ Constraint(...) * :constraint2 ^ Constraint(...)
```

Use operator `+` to glue two constraint trees together *without sharing* of any
variables. The operation will renumber the variables in the trees so that the
sets of variable indexes used by either tree are completely disjunct, and then
glue the trees together as with `*`:

```julia
two_independent_systems = my_system + other_system
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

Base.keys(x::ConstraintTree) = keys(elems(x))

Base.values(x::ConstraintTree) = values(elems(x))

Base.length(x::ConstraintTree) = length(elems(x))

Base.iterate(x::ConstraintTree) = iterate(elems(x))
Base.iterate(x::ConstraintTree, st) = iterate(elems(x), st)

Base.eltype(x::ConstraintTree) = eltype(elems(x))

Base.propertynames(x::ConstraintTree) = keys(x)

Base.getindex(x::ConstraintTree, sym::Symbol) = getindex(elems(x), sym)

#
# Tree-wide operations with variables
#

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`Constraint`](@ref).
"""
var_count(x::Constraint) = isempty(x.value.idxs) ? 0 : last(x.value.idxs)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`ConstraintTree`](@ref).
"""
var_count(x::ConstraintTree) = isempty(elems(x)) ? 0 : maximum(var_count.(values(elems(x))))

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`Constraint`](@ref) by the given increment.
"""
incr_var_idxs(x::Constraint, incr::Int) = Constraint(
    value = Value(idxs = x.value.idxs .+ incr, weights = x.value.weights),
    bound = x.bound,
)

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`ConstraintTree`](@ref) by the given
increment.
"""
incr_var_idxs(x::ConstraintTree, incr::Int) =
    ConstraintTree(elems = SortedDict(k => incr_var_idxs(v, incr) for (k, v) in elems(x)))

#
# Algebraic construction
#

Base.:^(pfx::Symbol, x::ConstraintTreeElem) = ConstraintTree(elems = SortedDict(pfx => x))

function Base.:+(a::ConstraintTree, b::ConstraintTree)
    offset = var_count(a)
    a * incr_var_idxs(b, offset)
end

function Base.:*(a_orig::ConstraintTree, b_orig::ConstraintTree)
    # TODO this might be much better inplace, but the copy luckily isn't
    # substantial in most cases
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
# Simple constraint trees
#

"""
$(TYPEDSIGNATURES)

Make a trivial constraint system that creates variables with indexes in
range `1:length(keys)` named in order as given by `keys`.

Parameter `bounds` is either `nothing` for creating unconstrained variables, a
single bound (of precise length 1) for creating all variables of the same
constraint, or an iterable object of same length as `keys` with individual
bounds for each variable in the same order as `keys`.

The individual bounds should be of type [`Bound`](@ref). To pass a single
interval bound for all variables, it is impossible to use a tuple (since its
length is 2); in such case use `bound = Ref((minimum, maximum))`, which has the
correct length.
"""
function allocate_variables(; keys::Vector{Symbol}, bounds = nothing)
    bs =
        isnothing(bounds) ? Base.Iterators.cycle(tuple(nothing)) :
        length(bounds) == 1 ? Base.Iterators.cycle(bounds) :
        length(bounds) == length(keys) ? bounds :
        error("lengths of bounds and keys differ for allocated variables")
    make_constraint_tree(
        k => Constraint(value = Value(Int[i], Float64[1.0]), bound = b) for
        ((i, k), b) in zip(enumerate(keys), bs)
    )
end
