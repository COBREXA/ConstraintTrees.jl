
"""
$(TYPEDEF)

A representation of a single constraint that limits a given value by a specific
[`Bound`](@ref).

Constraints may be scaled linearly, i.e., multiplied by real-number constants.

Constraints without a bound (`nothing` in the `bound` field) are possible;
these have no impact on the optimization problem but the associated `value`
becomes easily accessible for inspection and building other constraints.

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct Constraint{V}
    "A value (typically a [`LinearValue`](@ref) or a [`QuadraticValue`](@ref))
    that describes what the constraint constraints."
    value::V
    "A bound that the `value` must satisfy."
    bound::Bound = nothing

    function Constraint(v::T, b::Bound = nothing) where {T<:Value}
        new{T}(v, b)
    end
end

Constraint(v::T, b::Int) where {T<:Value} = Constraint(v, Float64(b))
Constraint(v::T, b::Tuple{X,Y}) where {T<:Value,X<:Real,Y<:Real} =
    Constraint(v, Float64.(b))

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
