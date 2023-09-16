
using SparseArrays

"""
$(TYPEDEF)

A representation of a "value" in a linear constrained optimization problem. The
value is an affine linear combination of several variables.

`Value`s can be combined additively and multiplied by real-number constants.

Multiplying two `Value`s yields a quadratic form (in a [`QValue`](@ref)).

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Value
    """
    Indexes of the variables used by the value. The indexes must always be
    sorted in strictly increasing order. The affine element has index 0.
    """
    idxs::Vector{Int}
    "Coefficients of the variables selected by `idxs`."
    weights::Vector{Float64}
end

"""
$(TYPEDSIGNATURES)

Construct a constant [`Value`](@ref) with a single affine element.
"""
Value(x::Real) = Value(idxs = [0], weights = [x])

Base.convert(::Type{Value}, x::Real) = Value(x)
Base.zero(::Type{Value}) = Value(idxs = [], weights = [])
Base.:+(a::Real, b::Value) = Value(a) + b
Base.:+(a::Value, b::Real) = a + Value(b)
Base.:-(a::Real, b::Value) = Value(a) - b
Base.:-(a::Value, b::Real) = a - Value(b)
Base.:-(a::Value, b::Value) = a + (-1 * b)
Base.:-(a::Value) = -1 * a
Base.:*(a::Real, b::Value) = b * a
Base.:*(a::Value, b::Real) = Value(idxs = a.idxs, weights = b .* a.weights)
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
value_product(x::Value, y) =
    sum(idx == 0 ? x.weights[i] : x.weights[i] * y[idx] for (i, idx) in enumerate(x.idxs))

"""
$(TYPEDSIGNATURES)

Shortcut for making a [`Value`](@ref) out of a linear combination defined by
the `SparseVector`.
"""
Value(x::SparseVector{Float64}) =
    let (idxs, weights) = findnz(x)
        Value(; idxs, weights)
    end
