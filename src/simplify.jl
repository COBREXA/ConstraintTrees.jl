
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
Internal simplifier implementation is stashed away in this module so that it
does not stand in the way of the "expected" use.

It's suggested to use [`simplify`](@ref ConstraintTrees.simplify) as a
general front-end.
"""
module Simplifier

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
    occurs::Set{Int} # constraint indexes (TODO sorted?)
    changed::Int
end

mutable struct ConstraintState{T}
    value::C.Value
    bound::C.Interval{T}
    address::Tuple
    changed::Int
end

mutable struct SimplifierState{T}
    tree::C.ConstraintTree
    vs::Vector{VariableState{T}}
    cs::Vector{ConstraintState{T}}
end

abstract type SimplifierResult end
struct SimplifierWorked end
struct SimplifierNoop end
struct SimplifierError
    msg::String
    problem::ConstraintTree
end

#
# Individual simplifiers
#

function check_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # do nothing but throw error if any of the intervals is empty
    return SimplifierNoop()
end

function imply_variable_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # go through the constraints that perhaps touch the variable and try to
    # tighten the interval
    return SimplifierNoop()
end

function dominate_constraint_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # if the bound implied by variables is smaller than the constraint bound in
    # any direction, remove the constraint bound
    return SimplifierNoop()
end

function drop_constraint_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # remove constraints where the bound is infinite
    # adjust all indexes in occurences
    return SimplifierNoop()
end

function sparsify_constraints!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # drop zeros everywhere to simplify work for others
    return SimplifierNoop()
end

function solve_singletons!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # find a singleton equality, and substitute for the variable
    return SimplifierNoop()
end

end # module Simplifier

"""
$(TYPEDSIGNATURES)

TODO
"""
function simplify(
    ct::ConstraintTree,
    carrier_type::Type{T};
    methods = (
        Simplifier.simplify_variable_bounds!,
        Simplifier.simplify_constraint_bounds,
        Simplifier.imply_variable_bounds!,
        Simplifier.dominate_constraint_bounds!,
        Simplifier.solve_constants!,
        Simplifier.solve_singletons!,
    ),
) where {T<:Real}
    #TODO (notes below)
    # From looking at the other simplifiers/presolvers, we should support:
    # - simplification of interval bounds to equalities
    # - substitution for provably constant&fixed variables
    # - removal of dominated constraints (also from "empty" constraints)
    # - solving&substitution of doubleton equations (lineq solve)
    #   - we can go for more complicated equations, but that would need a very
    #     good reason and much better heuristic
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
    # distinct safe_simplify() that does only safe stuff?
    #
    # Notably, we don't really need the "postsolve" here, because the CTs can
    # effectively carry the postsolve information all by itself.

    # collect variable state
    # TODO

    # filter out all constraints that still do anything, put them into a separate tree
    # TODO

    # initial simplifier state
    # TODO

    # run simplifiers until they all Noop or until there's error, or until
    # there's some kind of iteration limit hit
    # TODO

    # purge constraints from the original tree
    # TODO

    # TODO We should have a return value that prevents people from neglecting
    # the simplifier error check
    return
end
