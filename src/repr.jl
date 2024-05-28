
# Copyright (c) 2024, University of Luxembourg
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

"""
$(TYPEDSIGNATURES)

Represent a [`Tree`](@ref) using base Julia structures.

Useful for saving trees in JSON, YAML and other formats that can work with
`Dict`s and `Vector`s.
"""
to_repr(x::Tree{T}) where {T} =
    Dict(repr_label(Tree{T}) => Dict(String(k) => to_repr(v) for (k, v) in x))

repr_label(::Type{Tree}) = "tree"

"""
$(TYPEDSIGNATURES)

Create a [`Tree`](@ref) from base Julia structures.

Useful for loading trees from JSON, YAML and other formats that can work with
`Dict`s and `Vector`s.
"""
from_repr(::Type{Tree{T}}, x::AbstractDict) where {T<:Tree} =
    Tree{T}(Symbol(k) => from_repr(v) for (k, v) in x)
