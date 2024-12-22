
# Copyright (c) 2023-2024, University of Luxembourg
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

"""
$(TYPEDEF)

Abstract type of all bounds usable in constraints, including [`Between`](@ref)
and [`EqualTo`](@ref).

`length` of any `Bound` defaults to 1 in order to make broadcasting easier (in
turn, one can write e.g. `Constraint.(some_values, EqualTo(0.0))`).
"""
abstract type Bound end

Base.length(x::Bound) = return 1

"""
$(TYPEDEF)

Representation of an "equality" bound, which contains the single "equal to
this" value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct EqualToT{T} <: Bound
    "Equality bound value"
    equal_to::T
end

"""
$(TYPEDEF)

Shortcut for a `Float64`-typed equality bound implemented by
[`EqualToT`](@ref).
"""
const EqualTo = EqualToT{Float64}

EqualTo(x::Real) = EqualToT(Float64(x))

Base.:-(x::EqualToT) = -1 * x
Base.:*(a::EqualToT, b::Real) = b * a
Base.:*(a::Real, b::EqualToT) = EqualToT(a * b.equal_to)
Base.:/(a::EqualToT, b::Real) = EqualToT(a.equal_to / b)

"""
$(TYPEDEF)

Representation of an "interval" bound; consisting of lower and upper bound
value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct BetweenT{T} <: Bound
    "Lower bound"
    lower::T = typemin(T)
    "Upper bound"
    upper::T = typemax(T)
end

const Between = BetweenT{Float64}

BetweenT(x::T, y::T) where {T} = x < y ? BetweenT(x, y) : BetweenT(y, x)

Between(x::Real, y::Real) = BetweenT(Float64(x), Float64(y))

Base.:-(x::BetweenT) - 1 * x
Base.:*(a::BetweenT, b::Real) = b * a
Base.:/(a::BetweenT, b::Real) = BetweenT(a.lower / b, a.upper / b)
Base.:*(a::Real, b::BetweenT) = BetweenT(a * b.lower, a * b.upper)

"""
$(TYPEDEF)

Shortcut for all possible [`Bound`](@ref)s including the "empty" bound that
does not constraint anything (represented by `nothing`).
"""
const MaybeBound = Union{Nothing,Bound}
