
using SparseArrays

"""
$(TYPEDEF)

A representation of a quadratic form in the constrained optimization problem.
The `QuadraticValue` is an affine quadratic combination (i.e., a polynomial of maximum
degree 2) over the variables.

`QuadraticValue`s can be combined additively and multiplied by real-number constants.
The cleanest way to construct a `QuadraticValue` is to multiply two [`LinearValue`](@ref)s.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct QuadraticValue <: Value
    """
    Indexes of variable pairs used by the value. The indexes must always be
    sorted in strictly co-lexicographically increasing order, and the second
    index must always be greater than or equal to the first one. (Speaking in
    matrix terms, the indexing follows the indexes in an upper triangular
    matrix by columns.)

    As an outcome, the second index of the last index pair can be used as the
    upper bound of all variable indexes.

    As with [`LinearValue`](@ref), index `0` represents the
    affine element.
    """
    idxs::Vector{Tuple{Int,Int}}
    "Coefficient of the variable pairs selected by `idxs`."
    weights::Vector{Float64}
end

"""
$(TYPEDSIGNATURES)

Construct a constant [`QuadraticValue`](@ref) with a single affine element.
"""
QuadraticValue(x::Real) =
    iszero(x) ? QuadraticValue(idxs = [], weights = []) :
    QuadraticValue(idxs = [(0, 0)], weights = [x])

"""
$(TYPEDSIGNATURES)

Construct a [`QuadraticValue`](@ref) that is equivalent to a given [`LinearValue`](@ref).
"""
QuadraticValue(x::LinearValue) =
    QuadraticValue(idxs = [(0, idx) for idx in x.idxs], weights = x.weights)

Base.convert(::Type{QuadraticValue}, x::Real) = QuadraticValue(x)
Base.convert(::Type{QuadraticValue}, x::LinearValue) = QuadraticValue(x)
Base.zero(::Type{QuadraticValue}) = QuadraticValue(idxs = [], weights = [])
Base.:+(a::Real, b::QuadraticValue) = QuadraticValue(a) + b
Base.:+(a::QuadraticValue, b::Real) = a + QuadraticValue(b)
Base.:+(a::LinearValue, b::QuadraticValue) = QuadraticValue(a) + b
Base.:+(a::QuadraticValue, b::LinearValue) = a + QuadraticValue(b)
Base.:-(a::QuadraticValue) = -1 * a
Base.:-(a::Real, b::QuadraticValue) = QuadraticValue(a) - b
Base.:-(a::QuadraticValue, b::Real) = a - QuadraticValue(b)
Base.:-(a::LinearValue, b::QuadraticValue) = QuadraticValue(a) - b
Base.:-(a::QuadraticValue, b::LinearValue) = a - QuadraticValue(b)
Base.:*(a::Real, b::QuadraticValue) = b * a
Base.:*(a::QuadraticValue, b::Real) =
    QuadraticValue(idxs = a.idxs, weights = b .* a.weights)
Base.:-(a::QuadraticValue, b::QuadraticValue) = a + (-1 * b)
Base.:/(a::QuadraticValue, b::Real) =
    QuadraticValue(idxs = a.idxs, weights = a.weights ./ b)

"""
$(TYPEDSIGNATURES)

Internal helper for co-lex ordering of indexes.
"""
colex_le((a, b), (c, d)) = (b, a) < (d, c)

function Base.:+(a::QuadraticValue, b::QuadraticValue)
    r_idxs = Tuple{Int,Int}[]
    r_weights = Float64[]
    ai = 1
    ae = length(a.idxs)
    bi = 1
    be = length(b.idxs)

    while ai <= ae && bi <= be
        if colex_le(a.idxs[ai], b.idxs[bi])
            push!(r_idxs, a.idxs[ai])
            push!(r_weights, a.weights[ai])
            ai += 1
        elseif colex_le(b.idxs[bi], a.idxs[ai])
            push!(r_idxs, b.idxs[bi])
            push!(r_weights, b.weights[bi])
            bi += 1
        else # index pairs are equal; merge case
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
    QuadraticValue(idxs = r_idxs, weights = r_weights)
end

Base.:*(a::LinearValue, b::LinearValue) =
    let vals = a.weights .* b.weights'
        QuadraticValue(
            idxs = [(aidx, bidx) for bidx in b.idxs for aidx in a.idxs if aidx <= bidx],
            weights = [
                vals[ai, bi] for bi in eachindex(b.idxs) for
                ai in eachindex(a.idxs) if a.idxs[ai] <= b.idxs[bi]
            ],
        ) + QuadraticValue(
            idxs = [(bidx, aidx) for aidx in a.idxs for bidx in b.idxs if bidx < aidx],
            weights = [
                vals[ai, bi] for ai in eachindex(a.idxs) for
                bi in eachindex(b.idxs) if b.idxs[bi] < a.idxs[ai]
            ],
        )
    end

"""
$(TYPEDSIGNATURES)

Broadcastable shortcut for multiplying a [`LinearValue`](@ref) with itself.
Produces a [`QuadraticValue`](@ref).
"""
squared(a::LinearValue) = a * a

"""
$(TYPEDSIGNATURES)

Substitute anything vector-like as variable values into the [`QuadraticValue`](@ref)
and return the result.
"""
substitute(x::QuadraticValue, y) = sum(
    (
        let (idx1, idx2) = x.idxs[i]
            (idx1 == 0 ? 1.0 : y[idx1]) * (idx2 == 0 ? 1.0 : y[idx2]) * w
        end for (i, w) in enumerate(x.weights)
    ),
    init = 0.0,
)

"""
$(TYPEDSIGNATURES)

Shortcut for making a [`QuadraticValue`](@ref) out of a square sparse matrix. The
matrix is force-symmetrized by calculating `x' + x`.
"""
QuadraticValue(x::SparseMatrixCSC{Float64}) =
    let
        rs, cs, vals = findnz(x' + x)
        # Note: Correctness of this now relies on (row,col) index pairs coming
        # from `findnz` in correct (co-lexicographical) order. Might be worth
        # testing.
        QuadraticValue(
            idxs = [(rs[i], cs[i]) for i in eachindex(rs) if rs[i] <= cs[i]],
            weights = [vals[i] for i in eachindex(rs) if rs[i] <= cs[i]],
        )
    end