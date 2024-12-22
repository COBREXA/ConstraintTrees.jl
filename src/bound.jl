
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

Representation of an "EqualToT" bound; contains the single "equal to this"
value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct EqualToT{T} <: Bound
    "EqualToT bound value"
    equal_to::T
end

const EqualTo = EqualToT{Float64} # for compatibility, rm in 2.0

EqualTo(x::Real) = EqualTo(Float64(x))

Base.:-(x::EqualToT{T}) where {T} = -1 * x
Base.:*(a::EqualToT{T}, b::Real) where {T} = b * a
Base.:/(a::EqualToT{T}, b::Real) where {T} = EqualToT{T}(a.equal_to / b)
Base.:*(a::Real, b::EqualToT{T}) where {T} = EqualToT{T}(a * b.equal_to)

"""
$(TYPEDEF)

Representation of an "interval" bound; consisting of lower and upper bound
value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct BetweenT{T1, T2} <: Bound
    "Lower bound"
    lower::T1
    "Upper bound"
    upper::T2
end

const Between = BetweenT{Float64,Float64} # for compatibility, rm in 2.0

Between(x::Real, y::Real) = x < y ? Between(Float64(x), Float64(y)) : Between(Float64(y), Float64(x))

Base.:-(x::BetweenT{T1, T2}) where {T1, T2} = -1 * x
Base.:*(a::BetweenT{T1, T2}, b::Real) where {T1, T2} = b * a
Base.:/(a::BetweenT{T1, T2}, b::Real) where {T1, T2} = BetweenT{T1, T2}(a.lower / b, a.upper / b)
Base.:*(a::Real, b::BetweenT{T1, T2}) where {T1, T2} = BetweenT{T1, T2}(a * b.lower, a * b.upper)

"""
$(TYPEDEF)

Shortcut for all possible [`Bound`](@ref)s including the "empty" bound that
does not constraint anything (represented by `nothing`).
"""
const MaybeBound = Union{Nothing,Bound}
