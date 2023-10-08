
# TODO: this is a small wrap to "just add the AbstractDict" into the type so
# that we can re-use the AbstractDict-printing machinery from Base. It would be
# better to have AbstractDict as a proper supertype of Tree, but that currently
# seems very complex due to circularity of the definition.
struct ADWrap <: AbstractDict{Symbol,Any}
    x::Any
end

Base.isempty(x::ADWrap) = isempty(x.x)
Base.length(x::ADWrap) = length(x.x)
Base.iterate(x::ADWrap, y...) = iterate(x.x, y...)
Base.summary(io::IO, x::ADWrap) = summary(io, x.x)
Base.summary(io::IO, x::Tree{X}) where {X} =
    print(io, "$(Tree{X}) with ", length(x), length(x) == 1 ? " element" : " elements")

function Base.show(io::IO, mime::MIME"text/plain", x::Tree{X}) where {X}
    return show(io, mime, ADWrap(x))
end

function Base.show(io::IO, x::Tree{X}) where {X}
    return show(io, ADWrap(x))
end

function Base.show(io::IO, x::Constraint)
    if get(io, :compact, false)::Bool
        print(
            io,
            "$Constraint(",
            typeof(x.value),
            "(#= ... =#)",
            isnothing(x.bound) ? "" : ", $(x.bound)",
            ")",
        )
    else
        Base.show_default(io, x)
    end
end
