
# Copyright (c) 2023-2024, University of Luxembourg
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

import ConstructionBase
import DataStructures: SortedDict, SortedSet

"""
$(TYPEDEF)

A base "labeled tree" structure. Supports many interesting operations such as
merging.
"""
Base.@kwdef struct Tree{X}
    "Sorted dictionary of elements of the tree."
    elems::SortedDict{Symbol,Union{X,Tree{X}}} = SortedDict()

    """
    $(TYPEDSIGNATURES)

    Create a properly typed [`Tree`](@ref) out of anything that can be used to
    construct the inner dictionary.
    """
    Tree{X}(x...) where {X} = new{X}(SortedDict{Symbol,Union{X,Tree{X}}}(x...))

    # TODO Tree could be a proper subtype of AbstractDict, but currently that
    # fails due to circular use of the type in its own parameter. Might be hard
    # to do that properly.
end

"""
$(TYPEDSIGNATURES)

Get the elements dictionary out of the [`Tree`](@ref). This is useful for
getting an iterable container for working with many items at once.

Also, because of the overload of `getproperty` for `Tree`, this serves as a
simpler way to get the elements without an explicit use of `getfield`.
"""
elems(x::Tree) = getfield(x, :elems)

Base.isempty(x::Tree) = isempty(elems(x))

Base.length(x::Tree) = length(elems(x))

Base.iterate(x::Tree) = iterate(elems(x))
Base.iterate(x::Tree, st) = iterate(elems(x), st)

Base.get(x::Tree, k, default) = get(elems(x), k, default)
Base.get(f::Function, x::Tree, args...) = get(f, elems(x), args...)

Base.eltype(x::Tree) = eltype(elems(x))

Base.keytype(x::Tree) = keytype(elems(x))

Base.keys(x::Tree) = keys(elems(x))

Base.haskey(x::Tree, sym::Symbol) = haskey(elems(x), sym)
Base.haskey(x::Tree, str::String) = haskey(x, Symbol(str))

Base.valtype(x::Tree) = valtype(elems(x))

Base.values(x::Tree) = values(elems(x))

Base.getindex(x::Tree, sym::Symbol) = getindex(elems(x), sym)
Base.getindex(x::Tree, str::String) = getindex(x, Symbol(str))

Base.setindex!(x::Tree{X}, val::E, sym::Symbol) where {X,E<:Union{X,Tree{X}}} =
    setindex!(elems(x), val, sym)
Base.setindex!(x::Tree, val, str::String) = setindex!(x, val, Symbol(str))

Base.setindex(x::Tree{X}, val::E, sym::Symbol) where {X,E<:Union{X,Tree{X}}} =
    Tree{X}(elems(x)..., sym => val)
Base.setindex(x::Tree{X}, val::E, str::String) where {X,E<:Union{X,Tree{X}}} =
    Base.setindex(x, val, Symbol(str))

Base.delete!(x::Tree, sym::Symbol) = delete!(elems(x), sym)
Base.delete!(x::Tree, str::String) = delete!(x, Symbol(str))

Base.propertynames(x::Tree) = keys(x)

Base.hasproperty(x::Tree, sym::Symbol) = haskey(x, sym)

Base.getproperty(x::Tree, sym::Symbol) = elems(x)[sym]

Base.setproperty!(x::Tree{X}, sym::Symbol, val::E) where {X,E<:Union{X,Tree{X}}} =
    setindex!(elems(x), val, sym)

ConstructionBase.setproperties(x::Tree{T}, props::NamedTuple) where {T} =
    Tree{T}(elems(x)..., pairs(props)...)

#
# Algebraic construction
#

function Base.:^(pfx::Symbol, x::Tree{X}) where {X}
    Tree{X}(elems = SortedDict(pfx => x))
end

Base.:*(a::Tree, b::Tree...) = Base.merge(a, b...)

Base.merge(d::Tree, others::Tree...) = Base.mergewith(*, d, others...)
Base.merge(a::Base.Callable, d::Tree, others::Tree...) = Base.mergewith(a, d, others...)

function Base.mergewith(a::Base.Callable, d::Tree{X}, others::Tree...) where {X}
    Tree{X}(elems = mergewith(a, elems(d), elems.(others)...))
end

#
# Transforming trees
#

"""
$(TYPEDSIGNATURES)

Run a function over everything in the tree. The resulting tree will contain
elements of type specified by the 3rd argument. (This needs to be specified
explicitly, because the typesystem generally cannot guess the universal type
correctly.)

Note this is a specialized function specific for [`Tree`](@ref)s that behaves
differently from `Base.map`.
"""
function map(f, x, ::Type{T} = Constraint) where {T}
    go(x::Tree) = Tree{T}(k => go(v) for (k, v) in x)
    go(x) = f(x)

    go(x)
end

"""
$(TYPEDSIGNATURES)

Like [`map`](@ref), but keeping the "index" path and giving it to the function
as the first parameter. The "path" in the tree is reported as a tuple of
symbols.
"""
function imap(f, x, ::Type{T} = Constraint) where {T}
    go(ix, x::Tree) = Tree{T}(k => go(tuple(ix..., k), v) for (k, v) in x)
    go(ix, x) = f(ix, x)

    go((), x)
end

"""
$(TYPEDSIGNATURES)

Filter all branches and leaves in a tree, leaving only the ones where `f`
returns `true`.

Note that the branches are passed to `f` as well. Use [`filter_leaves`](@ref)
to only work with the leaf values.
"""
function filter(f, x::Tree{T}) where {T}
    go(x::Tree) = Tree{T}(k => go(v) for (k, v) in x if f(v))
    go(x) = f(x)

    go(x)
end

"""
$(TYPEDSIGNATURES)

Like [`filter`](@ref) but the filtering predicate function also receives the
"path" in the tree.
"""
function ifilter(f, x::Tree{T}) where {T}
    go(ix, x::Tree{T}) = Tree{T}(k => go(tuple(ix..., k), v) for (k, v) in x if f(v))
    go(ix, x) = f(ix, x)

    go((), x)
end

"""
$(TYPEDSIGNATURES)

Like [`filter`](@ref) but the filtering predicate function `f` only receives
the leaf values (i.e., no intermediate sub-trees).

In turn, the result will retain the whole subtree structure (even if empty).
"""
filter_leaves(f, x::Tree{T}) where {T} =
    let flt(x::Tree{T}) = true, flt(x) = f(x)
        filter(flt, x)
    end

"""
$(TYPEDSIGNATURES)

Combination of [`ifilter`](@ref) and [`filter_leaves`](@ref).
"""
ifilter_leaves(f, x::Tree{T}) where {T} =
    let flt(_, x::Tree{T}) = true, flt(i, x) = f(i, x)
        ifilter(flt, x)
    end

"""
$(TYPEDSIGNATURES)

Like [`map`](@ref), but discards the results, thus relying only on the side
effects of `f`.

Technically the name should be `for`, but that's a Julia keyword.
"""
function traverse(f, x)
    go(x::Tree) =
        for (_, v) in x
            go(v)
        end
    go(x) = begin
        f(x)
        return nothing
    end

    go(x)
end

"""
$(TYPEDSIGNATURES)

[`itraverse`](@ref) is to [`traverse`](@ref) like [`imap`](@ref) is to
[`map`](@ref).
"""
function itraverse(f, x)
    go(ix, x::Tree) =
        for (k, v) in x
            go(tuple(ix..., k), v)
        end
    go(ix, x) = begin
        f(ix, x)
        return nothing
    end

    go((), x)
end

"""
$(TYPEDSIGNATURES)

Reduce all items in a [`Tree`](@ref). As with `Base.reduce`, the reduction
order is not guaranteed, and the `init`ial value may be used any number of
times.

Note this is a specialized function specific for [`Tree`](@ref)s that behaves
differently from `Base.mapreduce`.
"""
function mapreduce(f, op, x; init = missing)
    go(x::Tree) = Base.reduce(op, (go(v) for (_, v) in x); init)
    go(x) = f(x)

    go(x)
end

"""
$(TYPEDSIGNATURES)

Like [`mapreduce`](@ref) but reporting the "tree directory path" where the reduced
elements occur, like with [`imap`](@ref). (Single elements from different
directory paths are not reduced together.)
"""
function imapreduce(f, op, x; init = missing)
    go(ix, x::Tree) =
        Base.reduce((a, b) -> op(ix, a, b), (go(tuple(ix..., k), v) for (k, v) in x); init)
    go(ix, x) = f(ix, x)

    go((), x)
end

"""
$(TYPEDSIGNATURES)

Like [`mapreduce`](@ref) but the mapped function is identity.

To avoid much type suffering, the `op`eration should ideally preserve the type
of its arguments. If you need to change the type, you likely want to use
[`mapreduce`](@ref).

Note this is a specialized function specific for [`Tree`](@ref)s that behaves
differently from `Base.reduce`.
"""
reduce(op, x; init = missing) = mapreduce(identity, op, x; init)

"""
$(TYPEDSIGNATURES)

Indexed version of [`reduce`](@ref) (internally uses [`imapreduce`](@ref)).
"""
ireduce(op, x; init = missing) = imapreduce((_, x) -> x, op, x; init)

"""
$(TYPEDSIGNATURES)

Run a function over the values in the intersection of paths in several trees (currently
there is support for 2 and 3 trees). This is an "inner join" -- all extra
elements are ignored. "Outer join" can be done via [`merge`](@ref).

As with [`map`](@ref), the inner type of the resulting tree must be specified
by the last parameter..

Note this is a specialized function specific for [`Tree`](@ref)s that behaves
differently from `Base.zip`.
"""
function zip(f, x, y, ::Type{T} = Constraint) where {T}
    go(x::Tree, y::Tree) = Tree{T}(
        k => go(x[k], y[k]) for k in intersect(SortedSet(keys(x)), SortedSet(keys(y)))
    )
    go(x, y) = f(x, y)

    go(x, y)
end

function zip(f, x, y, z, ::Type{T} = Constraint) where {T}
    go(x::Tree, y::Tree, z::Tree) = Tree{T}(
        k => go(x[k], y[k], z[k]) for
        k in intersect(SortedSet(keys(x)), SortedSet(keys(y)), SortedSet(keys(z)))
    )
    go(x, y, z) = f(x, y, z)

    go(x, y, z)
end

"""
$(TYPEDSIGNATURES)

Index-reporting variant of [`zip`](@ref) (see [`imap`](@ref) for reference).
"""
function izip(f, x, y, ::Type{T} = Constraint) where {T}
    go(ix, x::Tree, y::Tree) = Tree{T}(
        k => go(tuple(ix..., k), x[k], y[k]) for
        k in intersect(SortedSet(keys(x)), SortedSet(keys(y)))
    )
    go(ix, x, y) = f(ix, x, y)

    go((), x, y)
end

function izip(f, x, y, z, ::Type{T} = Constraint) where {T}
    go(ix, x::Tree, y::Tree, z::Tree) = Tree{T}(
        k => go(tuple(ix..., k), x[k], y[k], z[k]) for
        k in intersect(SortedSet(keys(x)), SortedSet(keys(y)), SortedSet(keys(z)))
    )
    go(ix, x, y, z) = f(ix, x, y, z)

    go((), x, y, z)
end

"""
$(TYPEDEF)

Helper type for implementation of `merge`-related functions.
"""
const OptionalTree = Union{Tree,Missing}

"""
$(TYPEDSIGNATURES)

Get a key from a tree that is possibly `missing`.
"""
optional_tree_get(::Missing, _) = missing
optional_tree_get(x, k) = get(x, k, missing)

"""
$(TYPEDSIGNATURES)

Get a sorted set of keys from a tree that is possibly `missing`.
"""
optional_tree_keys(::Missing) = SortedSet()
optional_tree_keys(x) = SortedSet(keys(x))

"""
$(TYPEDSIGNATURES)

Run a function over the values in the merge of all paths in the trees
(currently there is support for 2 and 3 trees). This is an "outer join"
equivalent of [`zip`](@ref).  Missing elements are replaced by `missing` in the
function call parameters, and the function may return `missing` to omit
elements.

Note this is a specialized function specific for [`Tree`](@ref)s that behaves
differently from `Base.merge`.
"""
function merge(f, x, y, ::Type{T} = Constraint) where {T}
    go(x::OptionalTree, y::OptionalTree) = Tree{T}(
        k => v for (k, v) in (
            k => go(optional_tree_get(x, k), optional_tree_get(y, k)) for
            k in union(optional_tree_keys(x), optional_tree_keys(y))
        ) if !ismissing(v)
    )
    go(x, y) = f(x, y)

    go(x, y)
end

function merge(f, x, y, z, ::Type{T} = Constraint) where {T}
    go(x::OptionalTree, y::OptionalTree, z::OptionalTree) = Tree{T}(
        k => v for (k, v) in (
            k => go(
                optional_tree_get(x, k),
                optional_tree_get(y, k),
                optional_tree_get(z, k),
            ) for k in
            union(optional_tree_keys(x), optional_tree_keys(y), optional_tree_keys(z))
        ) if !ismissing(v)
    )

    go(x, y, z) = f(x, y, z)

    go(x, y, z)
end

"""
$(TYPEDSIGNATURES)

Index-reporting variant of [`merge`](@ref) (see [`imap`](@ref) for reference).
"""
function imerge(f, x, y, ::Type{T} = Constraint) where {T}
    go(ix, x::OptionalTree, y::OptionalTree) = Tree{T}(
        k => v for (k, v) in (
            k => go(tuple(ix..., k), optional_tree_get(x, k), optional_tree_get(y, k)) for
            k in union(optional_tree_keys(x), optional_tree_keys(y))
        ) if !ismissing(v)
    )
    go(ix, x, y) = f(ix, x, y)

    go((), x, y)
end

function imerge(f, x, y, z, ::Type{T} = Constraint) where {T}
    go(ix, x::OptionalTree, y::OptionalTree, z::OptionalTree) = Tree{T}(
        k => v for (k, v) in (
            k => go(
                tuple(ix..., k),
                optional_tree_get(x, k),
                optional_tree_get(y, k),
                optional_tree_get(z, k),
            ) for k in
            union(optional_tree_keys(x), optional_tree_keys(y), optional_tree_keys(z))
        ) if !ismissing(v)
    )
    go(ix, x, y, z) = f(ix, x, y, z)

    go((), x, y, z)
end
