
# Copyright (c) 2025, University of Luxembourg
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
Internal presolver implementation is stashed away in this module so that it
does not stand in the way of the "expected" use.

It's suggested to use [`presolve!`](@ref ConstraintTrees.presolve!) as a
general front-end.
"""
module Presolver

using DocStringExtensions
import ConstraintTrees as C

struct Interval{T}
    low::T
    high::T
end

Base.isnan(x::Interval) = isnan(x.low) || isnan(x.high)
Base.:+(x::Real, y::Interval) = Interval(x + y.low, x + y.high)
Base.:+(x::Interval, y::Real) = y + x
Base.:+(x::Interval, y::Interval) = Interval(x.low + y.low, x.high + y.high)
Base.:-(x::Interval) = Interval(-x.high, -x.low)
Base.:-(x::Real, y::Interval) = x + (-y)
Base.:-(x::Interval, y::Real) = x + (-y)
Base.:*(x::Real, y::Interval) =
    x == 0 ? Interval(0, 0) :
    x > 0 ? Interval(x * y.low, x * y.high) : Interval(x * y.high, x * y.low)
Base.:*(x::Interval, y::Real) = y * x
Base.:*(x::Interval, y::Interval) =
    let a = x.low * y.low, b = x.low * y.high, c = x.high * y.low, d = x.high * y.high
        Interval(min(a, b, c, d), max(a, b, c, d))
    end
Base.:/(x::Interval, y::Real) = (1 / y) * x

C.squared(x::Interval) =
    let a = x.low * x.low, b = x.high * x.high
        Interval(x.low <= 0 && x.high >= 0 ? 0 : min(a, b), max(a, b))
    end

mutable struct VariableState{T}
    subst::Union{Nothing,C.Value} # replacement
    bound::Interval{T} # implied bound
    occurs::Set{Int} # constraint indexes
    updated::Int # vtime
end

mutable struct ConstraintState{T}
    ref::Ref{C.Constraint}
    bound::Interval{T} # implied bound at vtime
    errors::Int # beancounter for how much floaty error we are carrying
    updated::Int # vtime
end

end # module Presolver

"""
$(TYPEDSIGNATURES)

TODO
"""
function presolve!(ct::ConstraintTree)
    #TODO (notes below)
    # From looking at the other presolvers, we should support:
    # - simplification of interval bounds to equalities
    # - substitution for provably constant&fixed variables
    # - solving&substitution of doubleton equations (lineq solve)
    #   - we can go for more complicated equations, but that would need a very
    #     good reason and much better heuristic
    # - removal of dominated constraints (also from "empty" constraints)
    #
    # We may explode when infeasibilities get detected.
    #
    # If people give us their objective, we can also do:
    # - constantization of forced variables
    # - removal of free variables (these cause unbounded feasibility regions)
    #
    # We should report back the implied variable bounds.
    #
    # Not sure yet how configurable this should be; some of the operations are
    # completely safe but some have precision implications. Perhaps a single
    # "maximal error" knob would be sufficient? And maybe we should have a
    # distinct simplify!() that does only safe stuff?
    #
    # Notably, we don't really need the "postsolve" here, because the CTs can
    # effectively carry the postsolve information all by itself.
end
