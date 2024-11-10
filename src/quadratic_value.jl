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
    idxs::Vector{Tuple{Int, Int}}
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

"""
$(TYPEDSIGNATURES)

Helper function for implementing [`QuadraticValue`](@ref)-like objects. Given 2
sparse representations of quadratic combinations, it computes a "merged" one
with the values of both added together.

Zeroes are not filtered out.
"""
function add_sparse_quadratic_combination(
        a_idxs::Vector{Tuple{Int, Int}},
        a_weights::Vector{T},
        b_idxs::Vector{Tuple{Int, Int}},
        b_weights::Vector{T},
    )::Tuple{Vector{Tuple{Int, Int}}, Vector{T}} where {T}
    r_idxs = Tuple{Int, Int}[]
    r_weights = Float64[]
    ai = 1
    ae = length(a_idxs)
    bi = 1
    be = length(b_idxs)

    sizehint!(r_idxs, ae + be)
    sizehint!(r_weights, ae + be)

    while ai <= ae && bi <= be
        if colex_le(a_idxs[ai], b_idxs[bi])
            push!(r_idxs, a_idxs[ai])
            push!(r_weights, a_weights[ai])
            ai += 1
        elseif colex_le(b_idxs[bi], a_idxs[ai])
            push!(r_idxs, b_idxs[bi])
            push!(r_weights, b_weights[bi])
            bi += 1
        else # index pairs are equal; merge case
            push!(r_idxs, a_idxs[ai])
            push!(r_weights, a_weights[ai] + b_weights[bi])
            ai += 1
            bi += 1
        end
    end
    while ai <= ae
        push!(r_idxs, a_idxs[ai])
        push!(r_weights, a_weights[ai])
        ai += 1
    end
    while bi <= be
        push!(r_idxs, b_idxs[bi])
        push!(r_weights, b_weights[bi])
        bi += 1
    end
    return (r_idxs, r_weights)
end

Base.:+(a::QuadraticValue, b::QuadraticValue) =
let (idxs, weights) =
        add_sparse_quadratic_combination(a.idxs, a.weights, b.idxs, b.weights)
    QuadraticValue(; idxs, weights)
end

"""
$(TYPEDSIGNATURES)

Helper function for multiplying two [`LinearValue`](@ref)-like objects to make
a [`QuadraticValue`](@ref)-like object. This computes and merges the product.

Zeroes are not filtered out.
"""
function multiply_sparse_linear_combination(
        a_idxs::Vector{Int},
        a_weights::Vector{T},
        b_idxs::Vector{Int},
        b_weights::Vector{T},
    )::Tuple{Vector{Tuple{Int, Int}}, Vector{T}} where {T}
    vals = a_weights .* b_weights'
    return add_sparse_quadratic_combination(
        [(aidx, bidx) for bidx in b_idxs for aidx in a_idxs if aidx <= bidx],
        [
            vals[ai, bi] for bi in eachindex(b_idxs) for
                ai in eachindex(a_idxs) if a_idxs[ai] <= b_idxs[bi]
        ],
        [(bidx, aidx) for aidx in a_idxs for bidx in b_idxs if bidx < aidx],
        [
            vals[ai, bi] for ai in eachindex(a_idxs) for
                bi in eachindex(b_idxs) if b_idxs[bi] < a_idxs[ai]
        ],
    )
end

Base.:*(a::LinearValue, b::LinearValue) =
let (idxs, weights) =
        multiply_sparse_linear_combination(a.idxs, a.weights, b.idxs, b.weights)
    QuadraticValue(; idxs, weights)
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
