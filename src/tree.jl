
import DataStructures: SortedDict

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
end

"""
$(TYPEDSIGNATURES)

Get the elements dictionary out of the [`Tree`](@ref). This is useful for
getting an iterable container for working with many items at once.

Also, because of the overload of `getproperty` for `Tree`, this serves as a
simpler way to get the elements without an explicit use of `getfield`.
"""
elems(x::Tree) = getfield(x, :elems)

function Base.getproperty(x::Tree, sym::Symbol)
    elems(x)[sym]
end

Base.keys(x::Tree) = keys(elems(x))

Base.values(x::Tree) = values(elems(x))

Base.length(x::Tree) = length(elems(x))

Base.iterate(x::Tree) = iterate(elems(x))
Base.iterate(x::Tree, st) = iterate(elems(x), st)

Base.keytype(x::Tree) = keytype(elems(x))

Base.valtype(x::Tree) = valtype(elems(x))

Base.eltype(x::Tree) = eltype(elems(x))

Base.propertynames(x::Tree) = keys(x)

Base.getindex(x::Tree, sym::Symbol) = getindex(elems(x), sym)

#
# Algebraic construction
#

function Base.:^(pfx::Symbol, x::Tree{X}) where {X}
    Tree{X}(elems = SortedDict(pfx => x))
end

Base.:*(a::Tree, b::Tree) = merge(a, b)

Base.merge(d::Tree, others::Tree...) = mergewith(*, d, others...)
Base.merge(a::Base.Callable, d::Tree, others::Tree...) = mergewith(a, d, others...)

function Base.mergewith(a::Base.Callable, d::Tree{X}, others::Tree...) where {X}
    Tree{X}(elems = mergewith(a, elems(d), elems.(others)...))
end
