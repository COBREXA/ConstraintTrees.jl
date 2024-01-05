
# Copyright (c) 2023, University of Luxembourg
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

Base.eltype(x::Tree) = eltype(elems(x))

Base.keytype(x::Tree) = keytype(elems(x))

Base.keys(x::Tree) = keys(elems(x))

Base.haskey(x::Tree, sym::Symbol) = haskey(elems(x), sym)

Base.valtype(x::Tree) = valtype(elems(x))

Base.values(x::Tree) = values(elems(x))

Base.getindex(x::Tree, sym::Symbol) = getindex(elems(x), sym)

Base.setindex!(x::Tree{X}, val::E, sym::Symbol) where {X,E<:X} =
    setindex!(elems(x), val, sym)

Base.delete!(x::Tree, sym::Symbol) = delete!(elems(x), sym)

Base.propertynames(x::Tree) = keys(x)

Base.hasproperty(x::Tree, sym::Symbol) = haskey(x, sym)

Base.getproperty(x::Tree, sym::Symbol) = elems(x)[sym]

Base.setproperty!(x::Tree{X}, sym::Symbol, val::E) where {X,E<:X} =
    setindex!(elems(x), val, sym)

#
# Algebraic construction
#

function Base.:^(pfx::Symbol, x::Tree{X}) where {X}
    Tree{X}(elems = SortedDict(pfx => x))
end

Base.:*(a::Tree, b::Tree...) = merge(a, b...)

Base.merge(d::Tree, others::Tree...) = mergewith(*, d, others...)
Base.merge(a::Base.Callable, d::Tree, others::Tree...) = mergewith(a, d, others...)

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
"""
map(f, x::Tree, ::Type{T}) where {T} = Tree{T}(k => map(f, v, T) for (k, v) in x)

map(f, x, ::Type) = f(x)

"""
$(TYPEDSIGNATURES)

Run a function over the values in the intersection of several trees (currently there is support for 2 and 3 trees). Extra elements are ignored.

As with [`map`](@ref), the inner type of the resulting tree must be specified by the last parameter..
"""
zip(f, x::Tree, y::Tree, ::Type{T}) where {T} = Tree{T}(
    k => zip(f, x[k], y[k], T) for k in intersect(SortedSet(keys(x)), SortedSet(keys(y)))
)

zip(f, x::Tree, y::Tree, z::Tree, ::Type{T}) where {T} = Tree{T}(
    k => zip(f, x[k], y[k], z[k], T) for
    k in intersect(SortedSet(keys(x)), SortedSet(keys(y)), SortedSet(keys(z)))
)

zip(f, x, y, ::Type) = f(x, y)

zip(f, x, y, z, ::Type) = f(x, y, z)
