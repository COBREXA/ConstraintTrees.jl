
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

"""
$(TYPEDSIGNATURES)

An alternative of `Base.reduce` which does a "pairwise" reduction in the shape
of a binary merge tree, like in mergesort. In general this is a little more
complex, but if the reduced value "grows" with more elements added (such as
when adding a lot of [`LinearValue`](@ref)s together), this is able to prevent
a complexity explosion by postponing "large" reducing operations as much as
possible.

In the specific case with adding lots of [`LinearValue`](@ref)s and
[`QuadraticValue`](@ref)s together, this effectively squashes the reduction
complexity from something around `O(n^2)` to `O(n)` (with a little larger
constant factor.
"""
function preduce(op, xs; init = zero(eltype(xs)), stack_type = eltype(xs))
    n = length(xs)
    n == 0 && return init

    # This works by simulating integer increment and carry to organize the
    # additions in a (mildly begin-biased) tree. `used` stores the integer,
    # `val` the associated values.
    used = Vector{Bool}()
    val = Vector{stack_type}()

    for item in xs
        idx = 1
        while true
            if idx > length(used)
                push!(used, false)
                push!(val, init)
            end
            used[idx] || break
            item = op(item, val[idx]) # collect the bit and carry
            used[idx] = false
            idx += 1
        end
        val[idx] = item # hit a zero, no more carrying
        used[idx] = true
    end
    # collect all used bits
    item = init
    for idx = 1:length(used)
        if used[idx]
            item = op(item, val[idx])
        end
    end
    return item
end

"""
$(TYPEDSIGNATURES)

Alias for [`preduce`](@ref) that uses `+` as the operation.

Not as versatile as the `sum` from Base, but much faster for growing values
like [`LinearValue`](@ref)s and [`QuadraticValue`](@ref)s.
"""
sum(xs; init = zero(eltype(xs))) = preduce(+, xs; init)
