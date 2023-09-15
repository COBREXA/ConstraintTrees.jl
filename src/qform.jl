
using SparseArrays

"""
$(TYPEDEF)

A representation of a quadratic form in the constrained optimization problem.
The `QValue` is a linear combination of several variable pairs.

`QValue`s can be combined additively and multiplied by real-number constants.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct QValue
    """
    Indexes of variable pairs used by the value. The indexes are always sorted
    in lexicographically increasing order, and the second index is greater or
    equal than the first one.
    """
    idxs::Vector{Tuple{Int,Int}}
    "Coefficient of the variable pairs as used by the quadratic value"
    weights::Vector{Float64}
end

Base.zero(::Type{QValue}) = QValue(idxs = [], weights = [])
Base.:*(a::Real, b::QValue) = b * a
Base.:*(a::QValue, b::Real) = QValue(idxs = a.idxs, weights = b .* a.weights)
Base.:-(a::QValue, b::QValue) = a + (-1 * b)
Base.:-(a::QValue) = -1 * a
Base.:/(a::QValue, b::Real) = QValue(idxs = a.idxs, weights = a.weights ./ b)

function Base.:+(a::QValue, b::QValue)
    r_idxs = Tuple{Int,Int}[]
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

Shortcut for computing a product of the [`QValue`](@ref) and anything
vector-like.
"""
qvalue_product(x::QValue, y) = sum(x.weights .* y[first.(x.idxs)] .* y[last.(x.idxs)])

"""
$(TYPEDSIGNATURES)

Shortcut for making a [`QValue`](@ref) out of a square sparse matrix. The
matrix is force-symmetrized by calculating `x'+x`.
"""
QValue(x::SparseMatrixCSC{Float64}) =
    let
        rs, cs, vals = fndnz(x' + x)
        # note: this relies on (col,row) indexes being in correct order.
        QValue(
            idxs = [(cs[i], rs[i]) for i in eachindex(rs) if rs[i] <= cs[i]],
            weights = [vals[i] for i in eachindex(rs) if rs[i] <= cs[i]],
        )
    end

Base.:*(a::Value, b::Value) =
    let vals = a.weigths .* b.weights'
        QValue(
            idxs = [
                (aidx, bidx) for aidx in a.idxs for bidx in b.idxs if aidx <= bidx
            ]weights = [
                vals[ai, bi] for ai in eachindex(a.idxs) for
                bi in eachindex(b.idxs) if a.idxs[ai] <= b.idxs[bi]
            ],
        ) + QValue(
            idxs = [
                (bidx, aidx) for bidx in b.idxs for aidx in a.idxs if bidx < aidx
            ]weights = [
                vals[bi, ai] for bi in eachindex(b.idxs) for
                ai in eachindex(a.idxs) if b.idxs[bi] < a.idxs[ai]
            ],
        )
    end
