
function Base.show(io::IO, ::MIME"text/plain", x::Tree{X}) where {X}
    len = length(x)
    println(io, "$(Tree{X}) with $len $(len == 1 ? "element" : "elements"):")
    for (k, v) in elems(x)
        print(io, "  .$k = ")
        show(IOContext(io, :compact => true), v)
        println(io)
    end
end

function Base.show(io::IO, x::Tree{X}) where {X}
    print(io, "Tree{$X}(#= $(length(x)) elements =#)")
end

function Base.show(io::IO, x::Constraint)
    if get(io, :compact, false)::Bool
        print(
            io,
            "$Constraint($(typeof(x.value))(#= ... =#)$(isnothing(x.bound) ? "" : ", $(x.bound)"))",
        )
    else
        Base.show_default(io, x)
    end
end
