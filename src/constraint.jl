
"""
$(TYPEDEF)

Convenience shortcut for "interval" bound; consisting of lower and upper bound
value.
"""
const IntervalBound = Tuple{Float64,Float64}

"""
$(TYPEDEF)

Shortcut for possible bounds: either no bound is present (`nothing`), or a
single number is interpreted as an exact equality bound, or a tuple of 2 values
is interpreted as an interval bound.
"""
const Bound = Union{Nothing,Float64,IntervalBound}

"""
$(TYPEDEF)

A representation of a single constraint that limits the sum of a
[`Value`](@ref) and [`QValue`](@ref) by a specific [`Bound`](@ref).

Constraints may be multiplied by real-number constants.

Constraints without a bound (`nothing` in the `bound` field) are possible;
these have no impact on the optimization problem, but the associated `value`
and `qvalue` become easily accessible for inspection and building other
constraints.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Constraint
    """
    A [`Value`](@ref) that describes what linear combination of variables the
    constraint constraints.
    """
    value::Value = zero(Value)
    """"
    A [`QValue`](@ref) that describes what quadratic form the constraint
    constraints.
    """
    qvalue::Value = zero(QValue)
    "A bound that the sum of the `value` and `qvalue` the must satisfy."
    bound::Bound = nothing
end

Base.:-(a::Constraint) = -1 * a
Base.:*(a::Real, b::Constraint) = b * a
Base.:*(a::Constraint, b::Real) = Constraint(
    value = a.value * b,
    qvalue = a.qvalue * b,
    bound = a.bound isa Float64 ? a.bound * b :
            a.bound isa Tuple{Float64,Float64} ? a.bound .* b : nothing,
)
Base.:/(a::Constraint, b::Real) = Constraint(
    value = a.value / b,
    qvalue = qa.value / b,
    bound = a.bound isa Float64 ? a.bound / b :
            a.bound isa Tuple{Float64,Float64} ? a.bound ./ b : nothing,
)

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the value from the constraint that can be used
for broadcasting (as opposed to the dot-field access).
"""
value(x::Constraint) = x.value

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the quadratic form from the constraint that
can be used for broadcasting (as opposed to the dot-field access).
"""
qvalue(x::Constraint) = x.qvalue
