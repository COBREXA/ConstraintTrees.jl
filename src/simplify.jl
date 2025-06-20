
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

Interval{T}(x::Nothing) = Interval{T}(typemin(T), typemax(T))
Interval(x::EqualToT{T}) where {T} = Interval{T}(x.equal_to, x.equal_to)
Interval(x::BetweenT{T}) where {T} = Interval{T}(x.lower, x.upper)

mutable struct VariableState{T}
    subst::Union{Nothing,C.Value} # replacement
    bound::Interval{T} # implied bound
    occurs::Set{Int} # constraint indexes (TODO sorted?)
    changed::Int
end

isactive(x::VariableState) = !(isnothing(x.subst) || isempty(x.occurs))

mutable struct ConstraintState{T}
    value::C.Value
    bound::C.Interval{T}
    address::Tuple
    changed::Int
end

isactive(x::ConstraintState{T}) where {T} =
    !(x.bound.low == typemin(T) && x.bound.high == typemax(T))

mutable struct SimplifierState{T}
    vs::Vector{VariableState{T}}
    cs::Vector{ConstraintState{T}}
end

abstract type SimplifierResult end
struct SimplifierWorked <: SimplifierResult end
struct SimplifierNoop <: SimplifierResult end
struct SimplifierError <: SimplifierResult
    msg::String
    problem::ConstraintTree
end

#
# Individual simplifiers
#

function check_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    for (i, v)=enumerate(s.vs)
        v.bound.low <= v.bound.high && continue
        return SimplifierError("variable $i bounded to empty domain", ConstraintTree())
    end
    # TODO this might not be ever required since the bounds of constraints generally grow
    for (i, c) = enumerate(s.cs)
        c.bound.low <= c.bound.high && continue
        return SimplifierError("constraint domain became empty", foldr(^, c.address, init=Constraint(c.value)))
    end
    return SimplifierNoop()
end

function dominate_constraint_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # if the bound implied by variables is smaller than the constraint bound in
    # any direction, remove the constraint bound
    bounds = [v.bound for v = s.vs]
    did_work=false
    for c = s.cs
        implied_bound = C.substitute(c.value, bounds)
        # drop bounds if possible
        # TODO we can drop unnecessary bounds at the end, shouldn't we tighten them here instead?
        if implied_bound.low > c.bound.low
            c.bound.low = typemin(T)
        end
        if implied_bound.high < c.bound.high
            c.bound.high = typemax(T)
        end
        if implied_bound.low > c.bound.high || implied_bound.high < c.bound.low
            return SimplifierError("constraint domain insatisfiable, implied to $implied_bound", foldr(^, c.address, init=Constraint(c.value, C.BetweenT(c.bound.low, c.bound.high))))
        end
        # TODO should we detect and convert equalities here, to be able to invert more stuff?
    end
    return SimplifierNoop()
end

function drop_constraint_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # remove constraints where the bound is infinite
    return SimplifierNoop()
end

function sparsify_constraints!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # drop zeros everywhere to simplify work for others
    return SimplifierNoop()
end

function imply_variable_singleton_bounds!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # go through the simple that perhaps touch the variable and try to
    # tighten the interval
    return SimplifierNoop()
end

function drop_fixed_variables!(s::SimplifierState{T}, last::Int, vtime::Int) where {T}
    # substitute a constant for a fixed variable
    # TODO might deserve its own tolerance
    did_work = false
    for(i,v)=enumerate(s.vs)
        isactive(v) || continue
        v.bound.low != v.bound.high && continue
        # TODO add a substitution
    end
    return did_work ? SimplifierWorked() : SimplifierNoop()
end

end # module Simplifier

abstract type SimplifyResult end
struct SimplifyOK <: SimplifyResult
    constraints::ConstraintTree
    variables::Vector{Value}
    output::ConstraintTree
    iterations::Int
end
struct SimplifyFailed <: SimplifyResult
    msg::String, problem::ConstraintTree
    SimplifyFailed(x::Simplifier.SimplifyResult) = new(x.msg, x.problem)
end

"""
$(TYPEDSIGNATURES)

TODO
"""
function simplify(
    ct::ConstraintTree,
    carrier_type::Type{T};
    simplifiers = (
        Simplifier.check_bounds!,
        Simplifier.imply_variable_bounds,
        Simplifier.dominate_constraint_bounds!,
        Simplifier.drop_constraint_bounds!,
        Simplifier.sparsify_constraints!,
        Simplifier.solve_singletons!,
    ),
    iteration_limit = 100,
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

    state = let
        # collect variable state
        vs = [
            VariableState{T}(
                C.variable(one(T); idx = i),
                bound = Interval(nothing),
                Set{Int}(),
                0,
            ) for i = 1:var_count(ct)
        ]

        # filter out constraints that do anything, put them into a separate tree
        n_constraints = 0
        traverse(ct) do c
            if !isnothing(c.bound)
                n_constraints += 1
            end
        end
        cs = Vector{ConstraintState{T}}(undef, n_constraints)
        itraverse(ct) do path, c
            if isnothing(c.bound)
                return
            end
            cs[n_constraints] =
                ConstraintState{T}(c.value, Interval{T}(c.bound), path, 0)
            n_constraints -= 1
        end
        @assert n_constraints == 0

        # TODO update variable occurences!

        # initial simplifier state
        SimplifierState{T}(vs, cs)
    end

    # run simplifiers until they all Noop or until there's error
    last_vtime = zeros(Int, length(simplifiers))
    vtime = 1
    iteration = 0
    while iteration < iteration_limit
        iteration += 1
        bump_flag = false
        for (si, s) in enumerate(simplifiers)
            res = s(state, last_vtime[si], vtime)
            if res isa SimplifierError
                return SimplifyFailed(res)
            elseif res isa SimplifierNoop
                continue
            elseif res isa SimplifierWorked
                vtime += 1
                bump_flag = true
                continue
            end
            @assert false "we shouldn't get here"
        end

        bump_flag || break # no more stuff to do, terminate early early
    end

    # purge constraints from the original tree
    subst = TODO
    sct = map(ct) do
        C.Constraint(substitute(ct.value, subst)) # all bounds omitted!
    end

    return SimplifyOK(TODO, TODO, sct, iteration)
end
