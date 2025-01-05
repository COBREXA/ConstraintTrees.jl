
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

"""
$(TYPEDEF)

Abstract type of all bounds usable in constraints, including [`Between`](@ref)
and [`EqualTo`](@ref).

All [`Bound`](@ref)s are broadcastable as scalars by default.
"""
abstract type Bound end

Base.Broadcast.broadcastable(x::Bound) = return Ref(x)

"""
$(TYPEDSIGNATURES)

**Deprecation warning:** This is kept for backwards compatibility only, and
will be removed in a future release.
"""
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

"""
$(TYPEDSIGNATURES)

Construct an [`EqualTo`](@ref) bound.
"""
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

"""
$(TYPEDEF)

Shortcut for a `Float64`-typed interval bound implemented by
[`BetweenT`](@ref).
"""
const Between = BetweenT{Float64}

"""
$(TYPEDSIGNATURES)

Construct a [`Between`](@ref) bound. Additionally, this checks the order of the
values and puts them into a correct order.
"""
Between(x::Real, y::Real) =
    x < y ? BetweenT(Float64(x), Float64(y)) : BetweenT(Float64(y), Float64(x))

Base.:-(x::BetweenT) = -1 * x
Base.:*(a::BetweenT, b::Real) = b * a
Base.:*(a::Real, b::BetweenT) =
    a > 0 ? BetweenT(a * b.lower, a * b.upper) : BetweenT(a * b.upper, a * b.lower)
Base.:/(a::BetweenT, b::Real) =
    b > 0 ? BetweenT(a.lower / b, a.upper / b) : BetweenT(a.upper / b, a.lower / b)

"""
$(TYPEDEF)

Shortcut for all possible [`Bound`](@ref)s including the "empty" bound that
does not constraint anything (represented by `nothing`).
"""
const MaybeBound = Union{Nothing,Bound}
