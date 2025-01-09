
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

A representation of a single constraint that may limit the given value by a
specific [`Bound`](@ref).

Constraints without a bound (`nothing` in the `bound` field) are possible;
these have no impact on the optimization problem but the associated `value`
becomes easily accessible for inspection and building other constraints.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct Constraint
    "A value (typically a [`LinearValue`](@ref) or a [`QuadraticValue`](@ref))
    that describes what the constraint constraints."
    value::Value
    "A bound that the `value` must satisfy. Should be a subtype of
    [`MaybeBound`](@ref): Either `nothing` if there's no bound, or e.g.
    [`EqualToT`](@ref), [`BetweenT`](@ref) or similar structs."
    bound::MaybeBound = nothing

    function Constraint(v::Value, b::MaybeBound = nothing)
        new(v, b)
    end
end

Constraint(v::T, b::X) where {T<:Value,X<:Real} = Constraint(v, EqualToT{X}(b))
Constraint(v::T, b::Tuple{X,Y}) where {T<:Value,X<:Real,Y<:Real} =
    Constraint(v, BetweenT{X}(b...))

Base.:-(a::Constraint) =
    Constraint(value = -a.value, bound = isnothing(a.bound) ? nothing : -a.bound)
Base.:*(a::Real, b::Constraint) =
    Constraint(value = a * b.value, bound = isnothing(b.bound) ? nothing : a * b.bound)
Base.:*(a::Constraint, b::Real) =
    Constraint(value = a.value * b, bound = isnothing(a.bound) ? nothing : a.bound * b)
Base.:/(a::Constraint, b::Real) =
    Constraint(value = a.value / b, bound = isnothing(a.bound) ? nothing : a.bound / b)

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the value from the constraint that can be used
for broadcasting (as opposed to the dot-field access).
"""
value(x::Constraint) = x.value

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the bound from the constraint that can be used
for broadcasting (as opposed to the dot-field access).
"""
bound(x::Constraint) = x.bound

"""
$(TYPEDSIGNATURES)

Substitute anything vector-like as variables into the constraint's value,
producing a constraint with the new value.
"""
substitute(x::Constraint, y) = Constraint(substitute(x.value, y), x.bound)

"""
$(TYPEDSIGNATURES)

Overload of [`substitute_values`](@ref) for a single constraint.
"""
substitute_values(x::Constraint, y::AbstractVector, _ = eltype(y)) = substitute(value(x), y)
