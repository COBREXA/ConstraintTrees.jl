
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
Base.@kwdef mutable struct Constraint{V,B}
    "A value (typically a [`LinearValue`](@ref) or a [`QuadraticValue`](@ref))
    that describes what the constraint constraints."
    value::V
    "A bound that the `value` must satisfy. Should be a subtype of
    [`MaybeBound`](@ref): Either `nothing` if there's no bound, or e.g.
    [`EqualTo`](@ref), [`Between`](@ref) or similar structs."
    bound::B = nothing

    function Constraint(v::T, b::U = nothing) where {T<:Value,U<:MaybeBound}
        new{T,U}(v, b)
    end
end

Constraint(v::T, b::Real) where {T<:Value} = Constraint(v, EqualTo(b))
Constraint(v::T, b::Tuple{X,Y}) where {T<:Value,X<:Real,Y<:Real} =
    Constraint(v, Between(Float64.(b)...))

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
