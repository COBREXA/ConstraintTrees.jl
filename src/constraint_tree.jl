
import DataStructures: SortedDict

"""
$(TYPEDEF)

A hierarchical tree of many constraints that together describe a constrained
system. The tree may recursively contain other trees in a directory-like
structure; and these contain [`Constraint`](@ref)s and [`QConstraint`](@ref)s.

Members of the constraint tree are accessible via the record dot syntax as
properties; e.g. a constraint labeled with `:abc` in a constraint tree `t` may
be accessed as `t.abc` and as `t[:abc]`, and can be found while iterating
through `elems(t)`.

# Constructing the constraint trees

Use operator `^` to put a name on a constraint to convert it into a single
element [`ConstraintTree`](@ref):

```julia
x = :my_constraint ^ Constraint(Value(...), 1.0)
dir = :my_constraint_dir ^ x

dir.my_constraint_dir.my_constraint.bound   # returns 1.0
```

Use operator `*` to glue two constraint trees together while *sharing* the
variable indexes specified by the contained [`Value`](@ref)s and
[`QValue`](@ref)s.

```julia
my_constraints = :linear_limit ^ Constraint(...) * :quadratic_limit ^ QConstraint(...)
```

Use operator `+` to glue two constraint trees together *without sharing* of any
variables. The operation will renumber the variables in the trees so that the
sets of variable indexes used by either tree are completely disjunct, and then
glue the trees together as with `*`:

```julia
two_independent_systems = my_system + other_system
```

# Variable sharing limitations

Because of the renumbering, you can not easily use constraints and values from
the values *before* the addition in the constraint tree that is the result of
the addition. There is no check against that -- the resulting
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
    elems::SortedDict{Symbol,Union{Constraint,QConstraint,ConstraintTree}}

    ConstraintTree(x::SortedDict{Symbol,Union{Constraint,QConstraint,ConstraintTree}}) =
        new(x)

    """
    $(TYPEDSIGNATURES)

    Create a properly typed [`ConstraintTree`](@ref) out of anything that can be
    used to construct the inner dictionary.

    # Example
    ```julia
    ConstraintTree(:a => some_constraint, :b => another_constraint)
    ConstraintTree(c for c=constraints if !isnothing(c.bound))
    ```
    """
    ConstraintTree(x...) =
        new(SortedDict{Symbol,Union{Constraint,QConstraint,ConstraintTree}}(x...))
end

"""
$(TYPEDEF)

A shortcut for elements of the [`ConstraintTree`](@ref).
"""
const ConstraintTreeElem = Union{Constraint,QConstraint,ConstraintTree}


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

(This is a O(1) operation, relying on the order of indexes in
[`Value`](@ref)s.)
"""
var_count(x::Constraint) = isempty(x.value.idxs) ? 0 : last(x.value.idxs)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`Constraint`](@ref).

(This is a O(1) operation, relying on the co-lexicographical ordering of
indexes in [`QValue`](@ref)s)
"""
var_count(x::QConstraint) = isempty(x.qvalue.idxs) ? 0 : let (_, max) = last(x.qvalue.idxs)
    max
end

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`ConstraintTree`](@ref).
"""
var_count(x::ConstraintTree) = isempty(elems(x)) ? 0 : maximum(var_count.(values(elems(x))))

"""
$(TYPEDSIGNATURES)

Internal helper for manipulating variable indices.
"""
incr_var_idx(x::Int, incr::Int) = x == 0 ? 0 : x + incr

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`Constraint`](@ref) by the given increment.
"""
incr_var_idxs(x::Constraint, incr::Int) = Constraint(
    value = Value(idxs = incr_var_idx.(x.value.idxs, incr), weights = x.value.weights),
    bound = x.bound,
)

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`QConstraint`](@ref) by the given increment.
"""
incr_var_idxs(x::QConstraint, incr::Int) = QConstraint(
    qvalue = QValue(
        idxs = broadcast(ii -> incr_var_idx.(ii, incr), x.qvalue.idxs),
        weights = x.qvalue.weights,
    ),
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
    # TODO this might be much better inplace with an accumulator, but the copy
    # luckily isn't substantial in most cases
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

Allocate a single unnamed variable, returning a Constraint with an optionally
specified `bound`.
"""
variable(; bound = nothing) = Constraint(value = Value([1], [1.0]); bound)

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
function variables(; keys::Vector{Symbol}, bounds = nothing)
    bs =
        isnothing(bounds) ? Base.Iterators.cycle(tuple(nothing)) :
        length(bounds) == 1 ? Base.Iterators.cycle(bounds) :
        length(bounds) == length(keys) ? bounds :
        error("lengths of bounds and keys differ for allocated variables")
    ConstraintTree(
        k => Constraint(value = Value(Int[i], Float64[1.0]), bound = b) for
        ((i, k), b) in zip(enumerate(keys), bs)
    )
end
