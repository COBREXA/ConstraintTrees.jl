
# Copyright (c) 2023, University of Luxembourg
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

Abstract type of all values usable in constraints, including [`LinearValue`](@ref) and [`QuadraticValue`](@ref).
"""
abstract type Value end

"""
$(TYPEDSIGNATURES)

Returns any `Real`- or [`Value`](@ref)-typed `x`. This is a convenience
overload; typically one enjoys this more when extracting values from
[`Constraint`](@ref)s.
"""
value(x::T) where {T<:Union{Real,Value}} = x

"""
$(TYPEDSIGNATURES)

Substutite a value into a [`Value`](@ref)-typed `x`. This is a convenience
overload for the purpose of having [`substitute_values`](@ref) to run on both
[`Constraint`](@ref)s and [`Value`](@ref)s.
"""
substitute_values(x::Value, y::AbstractVector, _ = eltype(y)) = substitute(x, y)
