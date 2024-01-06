
# Copyright (c) 2023, University of Luxembourg
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

To make broadcasting work, `length(::Bound) = 1` has been extended. This allows
functions like [`variables`](@ref) to broadcast a single supplied bound across
all constraints.
"""
abstract type Bound end

Base.length(x::Bound) = 1

"""
$(TYPEDEF)

Representation of an "equality" bound; contains the single "equal to this"
value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct EqualTo <: Bound
    "Equality bound value"
    equal_to::Float64

    EqualTo(x::Real) = new(Float64(x))
end

Base.:-(x::EqualTo) = -1 * x
Base.:*(a::EqualTo, b::Real) = b * a
Base.:/(a::EqualTo, b::Real) = EqualTo(a.equal_to / b)
Base.:*(a::Real, b::EqualTo) = EqualTo(a * b.equal_to)

"""
$(TYPEDEF)

Representation of an "interval" bound; consisting of lower and upper bound
value.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct Between <: Bound
    "Lower bound"
    lower::Float64 = -Inf
    "Upper bound"
    upper::Float64 = Inf

    Between(x::Real, y::Real) =
        x < y ? new(Float64(x), Float64(y)) : new(Float64(y), Float64(x))
end

Base.:-(x::Between) = -1 * x
Base.:*(a::Between, b::Real) = b * a
Base.:/(a::Between, b::Real) = Between(a.lower / b, a.upper / b)
Base.:*(a::Real, b::Between) = Between(a * b.lower, a * b.upper)

"""
$(TYPEDEF)

Shortcut for all possible [`Bound`](@ref)s including the "empty" bound that
does not constraint anything (represented by `nothing`).
"""
const MaybeBound = Union{Nothing,Bound}
