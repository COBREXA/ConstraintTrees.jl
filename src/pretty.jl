
# Copyright (c) 2023, University of Luxembourg
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
    show(io, mime, ADWrap(x))
end

function Base.show(io::IO, x::Tree{X}) where {X}
    print(
        io,
        "$(Tree{X})(#= ",
        length(x),
        length(x) == 1 ? " element" : " elements",
        " =#)",
    )
end

function Base.show(io::IO, x::Constraint)
    if get(io, :compact, false)::Bool
        print(
            io,
            "$Constraint(",
            "$(typeof(x.value))",
            "(#= ... =#)",
            isnothing(x.bound) ? "" : ", $(x.bound)",
            ")",
        )
    else
        Base.show_default(io, x)
    end
end

#
# Pretty-printing interface
#

"""
$(TYPEDSIGNATURES)

Pretty-print a given object via other overloads of [`pretty`](@ref), defaulting
the output stream to standard output.
"""
pretty(x; kwargs...) = pretty(stdout, x; kwargs...)

"""
$(TYPEDSIGNATURES)

Default implementation of [`pretty`](@ref) defaults to `Base.show`.
"""
pretty(io::IO, x; kwargs...) = show(io, x; kwargs...)

"""
$(TYPEDSIGNATURES)

Pretty-print a nested tree into the `io`. This is the only overload of
[`pretty`](@ref) that is allowed to break lines.

The printing assumes a Unicode-capable `stdout` by default; the formatting can
be customized via keyword arguments (see other overloads of [`pretty`](@ref)
and [`pretty_tree`](@ref)).
"""
pretty(io::IO, x::Tree; kwargs...) = pretty_tree(io, x, "", ""; kwargs...)

"""
$(TYPEDSIGNATURES)

Pretty-print a constraint into the `io`.
"""
function pretty(io::IO, x::Constraint; kwargs...)
    pretty(io, x.value; kwargs...)
    isnothing(x.bound) || pretty(io, x.bound; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Pretty-print a linear value into the `io`.
"""
function pretty(io::IO, x::LinearValue; kwargs...)
    if isempty(x.idxs)
        print(io, "0")
    else
        join(io, ("$w" * pretty_var(i) for (i, w) in Base.zip(x.idxs, x.weights)), " + ")
    end
end

"""
$(TYPEDSIGNATURES)

Pretty-print a quadratic value into the `io`.
"""
function pretty(io::IO, x::QuadraticValue; kwargs...)
    if isempty(x.idxs)
        print(io, "0")
    else
        join(
            io,
            (
                "$w" * pretty_var(i) * pretty_var(j) for
                ((i, j), w) in Base.zip(x.idxs, x.weights)
            ),
            " + ",
        )
    end
end

"""
$(TYPEDSIGNATURES)

Default pretty-printing of a [`Bound`](@ref). Overloads that print bounds
should expect that they are ran right after printing of the [`Value`](@ref)s,
on the same line.
"""
function pretty(io::IO, x::Bound; default_bound_separator = "; ", kwargs...)
    print(io, bound_separator)
    show(io, x)
end

"""
$(TYPEDSIGNATURES)

Pretty-print an equality bound into the `io`.
"""
function pretty(io::IO, x::EqualTo; equal_to_sign = "=", kwargs...)
    print(io, " $equal_sign $(x.equal_to)")
end

"""
$(TYPEDSIGNATURES)

Pretty-print an interval bound into the `io`.
"""
function pretty(io::IO, x::Between; in_interval_sign = "∈", kwargs...)
    print(io, " $in_interval_sign [$(x.lower), $(x.upper)]")
end

#
# Pretty-printing helpers
#

"""
$(TYPEDSIGNATURES)

Internal helper for prettyprinting variable contributions. Does not print
anything for the zero "affine" variable.
"""
function pretty_var(i)
    if i == 0
        return ""
    else
        return "*x[$i]"
    end
end

"""
$(TYPEDSIGNATURES)

Internal helper for recursive prettyprinting of tree structures. Adds a
relatively legible Unicode scaffolding to highlight the tree structure. The
scaffolding can be customized via keyword arguments (which are passed here from
[`pretty`](@ref)).
"""
function pretty_tree(
    io::IO,
    x::Tree,
    pfx0::String,
    pfx::String;
    first_branch = "┬─",
    middle_branch = "├─",
    last_branch = "╰─",
    child_first_indent = "│ ╰─",
    child_indent = "│   ",
    lastchild_first_indent = "  ╰─",
    lastchild_indent = "   ",
    kwargs...,
)
    isempty(pfx0) || print(io, "\n")
    es = collect(elems(x))
    argpack = (;
        first_branch,
        middle_branch,
        last_branch,
        child_first_indent,
        child_indent,
        lastchild_first_indent,
        lastchild_indent,
        kwargs...,
    )
    if length(es) > 1
        (k, v) = es[begin]
        print(io, pfx0, first_branch, k)
        pretty_tree(io, v, pfx * child_first_indent, pfx * child_indent; argpack...)
    end
    for (k, v) in es[(begin+1):(end-1)]
        print(io, pfx, middle_branch, k)
        pretty_tree(io, v, pfx * child_first_indent, pfx * child_indent; argpack...)
    end
    if length(es) > 0
        (k, v) = es[end]
        print(io, pfx, last_branch, k)
        pretty_tree(io, v, pfx * lastchild_first_indent, pfx * lastchild_indent; argpack...)
    end
end

"""
$(TYPEDSIGNATURES)

Overload of [`pretty_tree`](@ref) for anything except [`Tree`](@ref)s -- this
utilizes [`pretty`](@ref) to finish a line with the "contents" of the tree
leaf.
"""
function pretty_tree(io::IO, x, pfx0::String, pfx::String; leaf_separator = ": ", kwargs...)
    print(io, leaf_separator)
    pretty(io, x; leaf_separator, kwargs...)
    print(io, "\n")
end
