
import DataStructures: SortedDict

"""
$(TYPEDEF)

A hierarchical tree of many constraints that together describe a constrained
system. The tree may recursively contain other trees in a directory-like
structure, which contain [`Constraint`](@ref)s as leaves.

Members of the constraint tree are accessible via the record dot syntax as
properties; e.g. a constraint labeled with `:abc` in a constraint tree `t` may
be accessed as `t.abc` and as `t[:abc]`, and can be found while iterating
through `elems(t)`.

# Constructing the constraint trees

Use operator `^` to put a name on a constraint to convert it into a single
element [`ConstraintTree`](@ref):

```julia
x = :my_constraint ^ Constraint(LinearValue(...), 1.0)
dir = :my_constraint_dir ^ x

dir.my_constraint_dir.my_constraint.bound   # returns 1.0
```

Use operator `*` to glue two constraint trees together while *sharing* the
variable indexes specified by the contained [`LinearValue`](@ref)s and
[`QuadraticValue`](@ref)s.

```julia
my_constraints = :some_constraints ^ Constraint(...) * :more_constraints ^ Constraint(...)
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
"""
const ConstraintTree = Tree{Constraint}

"""
$(TYPEDEF)

A shortcut for the type of the values in [`ConstraintTree`](@ref).
"""
const ConstraintTreeElem = Union{Constraint,ConstraintTree}

#
# Tree-wide operations with variables
#

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`Constraint`](@ref).
"""
var_count(x::Constraint) = var_count(x.value)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`ConstraintTree`](@ref).
"""
var_count(x::ConstraintTree) = isempty(elems(x)) ? 0 : maximum(var_count.(values(elems(x))))

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`LinearValue`](@ref). (This is a
O(1) operation, relying on the ordering of the indexes.)
"""
var_count(x::LinearValue) = isempty(x.idxs) ? 0 : last(x.idxs)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`QuadraticValue`](@ref). (This is a
O(1) operation, relying on the co-lexicographical ordering of indexes.)
"""
var_count(x::QuadraticValue) = isempty(x.idxs) ? 0 : let (_, max) = last(x.idxs)
    max
end

"""
$(TYPEDSIGNATURES)

Internal helper for manipulating variable indices.
"""
incr_var_idx(x::Int, incr::Int) = x == 0 ? 0 : x + incr

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`ConstraintTree`](@ref) by the given
increment.
"""
incr_var_idxs(x::ConstraintTree, incr::Int) =
    ConstraintTree(k => incr_var_idxs(v, incr) for (k, v) in elems(x))

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`ConstraintTree`](@ref) by the given
increment.
"""
incr_var_idxs(x::Constraint, incr::Int) =
    Constraint(value = incr_var_idxs(x.value, incr), bound = x.bound)

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`LinearValue`](@ref) by the given increment.
"""
incr_var_idxs(x::LinearValue, incr::Int) =
    LinearValue(idxs = incr_var_idx.(x.idxs, incr), weights = x.weights)

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a [`QuadraticValue`](@ref) by the given increment.
"""
incr_var_idxs(x::QuadraticValue, incr::Int) = QuadraticValue(
    idxs = broadcast(ii -> incr_var_idx.(ii, incr), x.idxs),
    weights = x.weights,
)

#
# Algebraic construction
#

Base.:^(pfx::Symbol, x::Constraint) = ConstraintTree(elems = SortedDict(pfx => x))

function Base.:+(a::ConstraintTree, b::ConstraintTree)
    offset = var_count(a)
    a * incr_var_idxs(b, offset)
end

Base.:*(a::ConstraintTree, b::Constraint) =
    error("Unable to merge a constraint directory with a constraint.")
Base.:*(a::Constraint, b::ConstraintTree) =
    error("Unable to merge a constraint with a constraint directory.")
Base.:*(a::Constraint, b::Constraint) = error("Unable to merge two constraints.")

#
# Simple constraint trees
#

"""
$(TYPEDSIGNATURES)

Allocate a single unnamed variable, returning a Constraint with an optionally
specified `bound`.
"""
variable(; bound = nothing) = Constraint(value = LinearValue([1], [1.0]); bound)

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
function variables(; keys::Union{Vector{Symbol},Set{Symbol}}, bounds = nothing)
    bs =
        isnothing(bounds) ? Base.Iterators.cycle(tuple(nothing)) :
        length(bounds) == 1 ? Base.Iterators.cycle(bounds) :
        length(bounds) == length(keys) ? bounds :
        error("lengths of bounds and keys differ for allocated variables")
    ConstraintTree(
        k => Constraint(value = LinearValue(Int[i], Float64[1.0]), bound = b) for
        ((i, k), b) in zip(enumerate(keys), bs)
    )
end

#
# Transforming the constraint trees
#

"""
$(TYPEDSIGNATURES)

Substitute variable values from `y` into the constraint tree's constraint's
values, getting a tree of "solved" constraint values for the given variable
assignment.
"""
constraint_values(x::ConstraintTree, y::Vector{Float64}) =
    tree_map(x, c -> substitute(value(c), y), Float64)

"""
$(TYPEDSIGNATURES)

Fallback for [`constraint_values`](@ref) for a single constraint.
"""
constraint_values(x::Constraint, y::Vector{Float64}) = substitute(value(x), y)
