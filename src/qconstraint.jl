
"""
$(TYPEDEF)

A representation of a single quadratic constraint that limits the
[`QValue`](@ref) by a specific [`Bound`](@ref). Apart from the quadratic
nature, type behaves just like the normal [`Constraint`](@ref).

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct QConstraint
    "A [`QValue`](@ref) that describes what the constraint constraints."
    qvalue::QValue
    "A bound that the `qvalue` must satisfy."
    bound::Bound = nothing

    QConstraint(v::QValue) = new(v, nothing)
    QConstraint(v::QValue, b::Bound) = new(v, b)
end

Base.convert(::Type{QConstraint}, x::Constraint) =
    QConstraint(qvalue = QValue(x.value), bound = x.bound)

"""
$(TYPEDSIGNATURES)

Overloaded constructor of [`Constraint`](@ref) that actually makes a
[`QConstraint`](@ref) because that is implied by the type of the value in `v`.
"""
Constraint(v::QValue, b::Bound = nothing) = QConstraint(v, b)

Base.:-(a::QConstraint) = -1 * a
Base.:*(a::Real, b::QConstraint) = b * a
Base.:*(a::QConstraint, b::Real) = QConstraint(
    qvalue = a.qvalue * b,
    bound = a.bound isa Float64 ? a.bound * b :
            a.bound isa Tuple{Float64,Float64} ? a.bound .* b : nothing,
)
Base.:/(a::QConstraint, b::Real) = QConstraint(
    qvalue = a.qvalue / b,
    bound = a.bound isa Float64 ? a.bound / b :
            a.bound isa Tuple{Float64,Float64} ? a.bound ./ b : nothing,
)

value(x::QConstraint) = x.qvalue
bound(x::QConstraint) = x.bound
