
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

A representation of a single constraint that limits the [`Value`](@ref) by a
specific [`Bound`](@ref).

Constraints may be multiplied by real-number constants.

Constraints without a bound (`nothing` in the `bound` field) are possible;
these have no impact on the optimization problem but the associated `value`
becomes easily accessible for inspection and building other constraints.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Constraint
    "A [`Value`](@ref) that describes what the constraint constraints."
    value::Value
    "A bound that the value must satisfy."
    bound::Bound = nothing
end

Base.:-(a::Constraint) = -1 * a
Base.:*(a::Real, b::Constraint) = b * a
Base.:*(a::Constraint, b::Real) = Constraint(
    value = a.value * b,
    bound = a.bound isa Float64 ? a.bound * b :
            a.bound isa Tuple{Float64,Float64} ? a.bound .* b : nothing,
)
Base.:/(a::Constraint, b::Real) = Constraint(
    value = a.value / b,
    bound = a.bound isa Float64 ? a.bound / b :
            a.bound isa Tuple{Float64,Float64} ? a.bound ./ b : nothing,
)

"""
$(TYPEDSIGNATURES)

Simple accessor for getting out the value from the constraint that can be used
for broadcasting (as opposed to the dot-field access).
"""
value(x::Constraint) = x.value
