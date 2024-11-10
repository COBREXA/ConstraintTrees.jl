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
struct ADWrap <: AbstractDict{Symbol, Any}
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
    return print(
        io,
        "$(Tree{X})(#= ",
        length(x),
        length(x) == 1 ? " element" : " elements",
        " =#)",
    )
end

function Base.show(io::IO, x::Constraint)
    return if get(io, :compact, false)::Bool
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
