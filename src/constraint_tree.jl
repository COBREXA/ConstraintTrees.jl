
# Copyright (c) 2023, University of Luxembourg
# Copyright (c) 2023, Heinrich-Heine University Duesseldorf
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
var_count(x::QuadraticValue) = isempty(x.idxs) ? 0 : last(last(x.idxs))

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
variable(; bound = nothing, idx = 1) =
    Constraint(value = LinearValue(Int[idx], Float64[1.0]); bound)

"""
$(TYPEDSIGNATURES)

Make a trivial constraint system that creates variables with indexes in range
`1:length(keys)` named in order as given by `keys`.

Parameter `bounds` is either `nothing` for creating variables without bounds
assigned to them, a single bound for creating variables with the same constraint
assigned to them all, or an iterable object of same length as `keys` with
individual bounds for each variable in the same order as `keys`.

The individual bounds should be subtypes of [`Bound`](@ref), or nothing. To pass
a single bound for all variables, use e.g. `bounds = EqualTo(0)`.
"""
function variables(; keys::AbstractVector{Symbol}, bounds = nothing)
    bs =
        isnothing(bounds) ? Base.Iterators.cycle(tuple(nothing)) :
        length(bounds) == 1 ? Base.Iterators.cycle(tuple(bounds)) :
        length(bounds) == length(keys) ? bounds :
        error("lengths of bounds and keys differ for allocated variables")
    ConstraintTree(
        k => variable(idx = i, bound = b) for ((i, k), b) in Base.zip(enumerate(keys), bs)
    )
end

"""
$(TYPEDSIGNATURES)

Allocate a variable for each item in a constraint tree (or any other kind of
tree) and return a [`ConstraintTree`](@ref) with variables bounded by the
`makebound` function, which converts a given tree element's value into a bound
for the corresponding variable.
"""
function variables_for(makebound, ts::Tree)
    var_idx = 0
    map(ts, Constraint) do x
        var_idx += 1
        variable(idx = var_idx, bound = makebound(x))
    end
end

"""
$(TYPEDSIGNATURES)

Like [`variables_for`](@ref) but the `makebound` function also receives a path
to the variable, as with [`imap`](@ref).
"""
function variables_ifor(makebound, ts::Tree)
    var_idx = 0
    imap(ts, Constraint) do path, x
        var_idx += 1
        variable(idx = var_idx, bound = makebound(path, x))
    end
end

#
# Transforming the constraint trees
#

"""
$(TYPEDSIGNATURES)

Substitute variable values from `y` into the constraint tree's constraint's
values, getting a tree of "solved" constraint values for the given variable
assignment.

The third argument forces the output type (it is forwarded to
[`map`](@ref)). The type gets defaulted from `eltype(y)`.
"""
substitute_values(x::Tree, y::AbstractVector, ::Type{T} = eltype(y)) where {T} =
    map(x, T) do c
        substitute_values(c, y)
    end
