
# Copyright (c) 2023-2025, University of Luxembourg
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

import DataStructures: SortedDict, SortedSet

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
variable_count(x::Constraint) = variable_count(x.value)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`ConstraintTree`](@ref).
"""
variable_count(x::ConstraintTree) = isempty(x) ? 0 : maximum(variable_count.(values(x)))

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`LinearValue`](@ref). (This is a
O(1) operation, relying on the ordering of the indexes.)
"""
variable_count(x::LinearValueT) = isempty(x.idxs) ? 0 : last(x.idxs)

"""
$(TYPEDSIGNATURES)

Find the expected count of variables in a [`QuadraticValue`](@ref). (This is a
O(1) operation, relying on the co-lexicographical ordering of indexes.)
"""
variable_count(x::QuadraticValueT) = isempty(x.idxs) ? 0 : last(last(x.idxs))

"""
Old name for [`variable_count`](@ref).

**Deprecation warning:** This will be removed in a future release.
"""
const var_count = variable_count

"""
$(TYPEDSIGNATURES)

Offset all variable indexes in a structure `x` by the given increment.

Internally, this uses [`renumber_variables`](@ref).

# Extensibility note

If you extend the functionality of ConstraintTrees by overloading
[`increase_variable_indexes`](@ref), consider instead providing the overload
for [`renumber_variables`](@ref) which grants more functionality, mainly
variable pruning.
"""
increase_variable_indexes(x, incr::Int) =
    renumber_variables(x) do idx
        idx == 0 ? 0 : idx + incr
    end

"""
Old name for [`increase_variable_indexes`](@ref).

**Deprecation warning:** This will be removed in a future release.
"""
const incr_var_idxs = increase_variable_indexes

"""
$(TYPEDSIGNATURES)

Push all variable indexes found in `x` to the `out` container.

(The container needs to support the standard `push!`.)
"""
collect_variables!(x::Constraint, out) = collect_variables!(x.value, out)
collect_variables!(x::LinearValueT, out) =
    for idx in x.idxs
        push!(out, idx)
    end
collect_variables!(x::QuadraticValueT, out) =
    for (idx, idy) in x.idxs
        push!(out, idx, idy)
    end
collect_variables!(x::Tree{T}, out::C) where {T,C} =
    collect_variables!.(values(x), Ref(out))

# helpers for the overload of collect_variables! below:
struct ContainerF{F}
    f::F
end

Base.push!(x::ContainerF, vs...) = x.f.(vs)

"""
$(TYPEDSIGNATURES)

Overload of [`collect_variables!`](@ref) that calls a given function with all
variable indexes found in `x`.
"""
collect_variables!(out::Function, x) = collect_variables!(x, ContainerF(out))

"""
$(TYPEDSIGNATURES)

Prune the unused variable indexes from an object `x` (such as a
[`ConstraintTree`](@ref)).

This first runs [`collect_variables!`](@ref) to determine the actual used
variables, then calls [`renumber_variables`](@ref) to create a renumbered
object.
"""
function prune_variables(x)
    vars = SortedSet{Int}()
    collect_variables!(x, vars)
    push!(vars, 0)
    vv = collect(vars)
    @assert vv[1] == 0 "variable indexes are broken"
    return renumber_variables(x, SortedDict(vv .=> 0:(length(vv)-1)))
end

"""
$(TYPEDSIGNATURES)

Renumber all variables in an object (such as [`ConstraintTree`](@ref)). The new
variable indexes are taken from the `mapping` parameter at the index of the old
variable's index.

The `mapping` is assumed to be an array-like object (i.e., it must support
`getindex`, which is used to retrieve the new index for each original variable
index).

!!! warning "The variable index mapping must be monotonic!"

    [`renumber_variables`](@ref) does **not** run any consistency checks on the
    result. The `mapping` must therefore be monotonically increasing, and the
    zero index must map to itself, otherwise invalid [`Value`](@ref)s will be
    produced.
"""
renumber_variables(x::Tree{T}, mapping) where {T} =
    ConstraintTree(k => renumber_variables(v, mapping) for (k, v) in x)
renumber_variables(x::Constraint, mapping) =
    Constraint(renumber_variables(x.value, mapping), x.bound)
renumber_variables(x::LinearValueT, mapping) =
    LinearValueT(idxs = [mapping[idx] for idx in x.idxs], weights = x.weights)
renumber_variables(x::QuadraticValueT, mapping) = QuadraticValueT(
    idxs = [(mapping[idx], mapping[idy]) for (idx, idy) in x.idxs],
    weights = x.weights,
)

"""
$(TYPEDSIGNATURES)

An overload of [`renumber_variables`](@ref) that allows `mapping` to be a
single-parameter `Function`.
"""
renumber_variables(mapping::Function, x) = renumber_variables(x, ContainerF(mapping))

# helper for above
Base.getindex(x::ContainerF{F}, idx) where {F} = x.f(idx)

"""
$(TYPEDSIGNATURES)

Remove variable references from all [`Value`](@ref)s in the given object
(usually a [`ConstraintTree`](@ref)) where the variable weight is exactly zero.
"""
drop_zeros(x::Tree{T}) where {T} = ConstraintTree(k => drop_zeros(v) for (k, v) in x)
drop_zeros(x::Constraint) = Constraint(drop_zeros(x.value), x.bound)
drop_zeros(x::LinearValueT) =
    LinearValueT(idxs = x.idxs[x.weights .!= 0], weights = x.weights[x.weights .!= 0])
drop_zeros(x::QuadraticValueT) =
    QuadraticValueT(idxs = x.idxs[x.weights .!= 0], weights = x.weights[x.weights .!= 0])

#
# Algebraic construction
#

Base.:^(pfx::Symbol, x::Constraint) = ConstraintTree(elems = SortedDict(pfx => x))

function Base.:+(a::ConstraintTree, b::ConstraintTree)
    offset = variable_count(a)
    a * increase_variable_indexes(b, offset)
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
variable(weight::T = 1.0; bound = nothing, idx = 1) where {T} =
    Constraint(value = LinearValue(Int[idx], T[weight]); bound)

"""
$(TYPEDSIGNATURES)

Make a trivial constraint system that creates variables with indexes in range
`1:length(keys)` named in order as given by `keys`.

The individual bounds should be subtypes of [`Bound`](@ref), or nothing (which
is the default). The bounds are broadcasted; to pass a single bound for all
variables, one can use e.g. `bounds = EqualTo(0)`.
"""
variables(weight = 1.0; keys::AbstractVector{Symbol}, bounds = Ref(nothing)) =
    let go((i, k), b) = k => variable(weight, idx = i, bound = b)
        ConstraintTree(go.(enumerate(keys), bounds)...)
    end

"""
$(TYPEDSIGNATURES)

Allocate a variable for each item in a constraint tree (or any other kind of
tree) and return a [`ConstraintTree`](@ref) with variables bounded by the
`makebound` function, which converts a given tree element's value into a bound
for the corresponding variable.
"""
function variables_for(makebound, ts::Tree, weight = 1.0)
    var_idx = 0
    map(ts, Constraint) do x
        var_idx += 1
        variable(weight; idx = var_idx, bound = makebound(x))
    end
end

"""
$(TYPEDSIGNATURES)

Like [`variables_for`](@ref) but the `makebound` function also receives a path
to the variable, as with [`imap`](@ref).
"""
function variables_ifor(makebound, ts::Tree, weight = 1.0)
    var_idx = 0
    imap(ts, Constraint) do path, x
        var_idx += 1
        variable(weight, idx = var_idx, bound = makebound(path, x))
    end
end

#
# Transforming the constraint trees
#

"""
$(TYPEDSIGNATURES)

Substitute variable values from `y` into the constraint tree's constraint's
values, getting a tree with modified constraints.

In a typical application, this can be used together with
[`prune_variables`](@ref) to fix a subset of variables to known values and
effectively remove them from the problem.

Cf. [`substitute_values`](@ref), which creates a tree of "plain" values with
no constraints.
"""
substitute(x::ConstraintTree, y::AbstractVector) =
    map(x) do c
        substitute(c, y)
    end

"""
$(TYPEDSIGNATURES)

Substitute variable values from `y` into the constraint tree's constraint's
values, getting a tree of "solved" constraint values for the given variable
assignment.

The third argument forces the output type (it is forwarded to
[`map`](@ref)). The type gets defaulted from `eltype(y)`.

To preserve the constraints in the tree, use [`substitute`](@ref).
"""
substitute_values(x::Tree, y::AbstractVector, ::Type{T} = eltype(y)) where {T} =
    map(x, T) do c
        substitute_values(c, y)
    end
