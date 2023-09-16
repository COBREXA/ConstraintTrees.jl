
"""
$(TYPEDEF)

A representation of a single quadratic constraint that limits the
[`QValue`](@ref) by a specific [`Bound`](@ref). Apart from the quadratic
nature, type behaves just like the normal [`Constraint`](@ref).

# Fields
$(TYPEDFIELDS)
"""
Base.@kwdef struct Constraint
    "A [`QValue`](@ref) that describes what the constraint constraints."
    qvalue::QValue
    "A bound that the `qvalue` must satisfy."
    bound::Bound = nothing
end

Base.convert(::Type{QConstraint}, x::Constraint) =
    QConstraint(qvalue = QValue(x.value), bound = x.bound)

Base.:-(a::QConstraint) = -1 * a
Base.:*(a::Real, b::QConstraint) = b * a
Base.:*(a::QConstraint, b::Real) = AConstraint(
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
