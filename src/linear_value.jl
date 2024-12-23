
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

A representation of a "value" in a linear constrained optimization problem. The
value is an affine linear combination of several variables, weighted by
coefficients of the parameter type `T`.

`LinearValueT`s can be combined additively and multiplied by real-number
constants.  Multiplying two `LinearValueT`s yields a quadratic form (in a
[`QuadraticValueT`](@ref)).

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct LinearValueT{T} <: Value
    """
    Indexes of the variables used by the value. The indexes must always be
    sorted in strictly increasing order. The affine element has index 0.
    """
    idxs::Vector{Int}
    "Coefficients of the variables selected by `idxs`."
    weights::Vector{T}
end

"""
$(TYPEDEF)

A shortcut for a [`LinearValueT`](@ref) over `Float64`s.
"""
const LinearValue = LinearValueT{Float64}

"""
$(TYPEDSIGNATURES)

Construct a constant-valued [`LinearValueT`](@ref) with a single affine
element.
"""
LinearValueT(x::R) where {R<:Real} =
    iszero(x) ? zero(LinearValueT{R}) : LinearValueT{R}(idxs = [0], weights = R[x])

"""
$(TYPEDSIGNATURES)

Construct a constant-valued [`LinearValue`](@ref) with a single affine element.
"""
LinearValue(x::Real) = LinearValueT(Float64(x))

Base.convert(::Type{LinearValueT{T}}, x::Real) where {T} = LinearValueT{T}(convert(T, x))
Base.zero(::Type{T}) where {T<:LinearValueT} = T(idxs = [], weights = [])
Base.:+(a::Real, b::LinearValueT{T}) where {T} = LinearValueT{T}(a) + b
Base.:+(a::LinearValueT{T}, b::Real) where {T} = a + LinearValueT{T}(b)
Base.:-(a::Real, b::LinearValueT{T}) where {T} = LinearValueT{T}(a) - b
Base.:-(a::LinearValueT{T}, b::Real) where {T} = a - LinearValueT{T}(b)
Base.:-(a::LinearValueT, b::LinearValueT) = a + (-1 * b)
Base.:-(a::LinearValueT) = -1 * a
Base.:*(a::Real, b::LinearValueT) = b * a
Base.:*(a::LinearValueT, b::Real) = LinearValueT(idxs = a.idxs, weights = b .* a.weights)
Base.:/(a::LinearValueT, b::Real) = LinearValueT(idxs = a.idxs, weights = a.weights ./ b)

"""
$(TYPEDSIGNATURES)

Helper function for implementing [`LinearValue`](@ref)-like objects. Given
"sparse" representations of linear combinations, it computes a "merged" linear
combination of 2 values added together.

Zeroes are not filtered out.
"""
function add_sparse_linear_combination(
    a_idxs::Vector{Int},
    a_weights::Vector{T},
    b_idxs::Vector{Int},
    b_weights::Vector{T},
)::Tuple{Vector{Int},Vector{T}} where {T}
    r_idxs = Int[]
    r_weights = T[]
    ai = 1
    ae = length(a_idxs)
    bi = 1
    be = length(b_idxs)

    sizehint!(r_idxs, ae + be)
    sizehint!(r_weights, ae + be)

    while ai <= ae && bi <= be
        if a_idxs[ai] < b_idxs[bi]
            push!(r_idxs, a_idxs[ai])
            push!(r_weights, a_weights[ai])
            ai += 1
        elseif a_idxs[ai] > b_idxs[bi]
            push!(r_idxs, b_idxs[bi])
            push!(r_weights, b_weights[bi])
            bi += 1
        else # a_idxs[ai] == b_idxs[bi] -- merge case
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

Base.:+(a::LinearValueT{T}, b::LinearValueT{T}) where {T} =
    let
        (idxs, weights) =
            add_sparse_linear_combination(a.idxs, a.weights, b.idxs, b.weights)
        LinearValueT{T}(; idxs, weights)
    end

"""
$(TYPEDSIGNATURES)

Substitute anything vector-like as variable values into a [`LinearValueT`](@ref)
and return the result.
"""
substitute(x::LinearValueT, y) = sum(
    (idx == 0 ? x.weights[i] : x.weights[i] * y[idx] for (i, idx) in enumerate(x.idxs)),
    init = 0.0,
)

"""
$(TYPEDSIGNATURES)

Shortcut for making a [`LinearValue`](@ref) out of a linear combination defined
by the `SparseVector`.
"""
LinearValue(x::SparseVector{Float64}) = LinearValueT(x)

"""
$(TYPEDSIGNATURES)

Generalized constructor for [`LinearValueT`](@ref)s from sparse vectors.
"""
LinearValueT(x::SparseVector{T}) where {T} =
    let (idxs, weights) = findnz(x)
        LinearValueT{T}(; idxs, weights)
    end
