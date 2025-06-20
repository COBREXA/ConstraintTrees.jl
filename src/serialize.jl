
# Copyright (c) 2025, University of Luxembourg
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

#
# Labeling business
#
# (We somehow need to get the polymorphism into the Dict representation)
#

"""
$(TYPEDEF)

Helper type for doing overloads for serialization and deserialization.
"""
struct SerializationLabel{L} end

"""
$(TYPEDSIGNATURES)

Deserialize a [`Bound`](@ref) into a type described by the label.

This should be overloaded for custom bound types that are supposed to get
serialized.
"""
deserialize_bound(::Type{SerializationLabel{:between}}, x) = deserialize(Between, x)
deserialize_bound(::Type{SerializationLabel{:equal_to}}, x) = deserialize(EqualTo, x)

"""
$(TYPEDSIGNATURES)

Produce a type label for serializing the given bound type.

Overloads should correspond to [`deserialize_bound`](@ref).
"""
serialize_bound_label(::Type{Between}) = return :between
serialize_bound_label(::Type{EqualTo}) = return :equal_to

"""
$(TYPEDSIGNATURES)

Deserialize a [`Value`](@ref) into a type described by the label.

This should be overloaded for custom value types that are supposed to get
serialized.
"""
deserialize_value(::Type{SerializationLabel{:linear}}, x) = deserialize(LinearValue, x)
deserialize_value(::Type{SerializationLabel{:quadratic}}, x) =
    deserialize(QuadraticValue, x)

"""
$(TYPEDSIGNATURES)

Produce a type label for serializing the given value type.

Overloads should correspond to [`deserialize_value`](@ref).
"""
serialize_value_label(::Type{LinearValue}) = return :linear
serialize_value_label(::Type{QuadraticValue}) = return :quadratic

#
# Deserialization
#

"""
$(TYPEDSIGNATURES)

Reconstruct a [`Tree`](@ref) from a dictionary "description" as produced by
[`serialize`](@ref).

The trees are labeled with explicit key `"tree"`, which allows the
implementation to recognize the subtrees from leaf elements.
"""
deserialize(::Type{Tree{T}}, x::Dict) where {T} = Tree{T}(
    Symbol(k) => if v isa Dict && length(keys(v))==1 && first(keys(x))=="tree"
        deserialize(Tree{T}, v)
    else
        deserialize(T, v)
    end for (k, v) in x["tree"]
)

"""
$(TYPEDSIGNATURES)

Reconstruct a [`Constraint`](@ref) from a dictionary as produced by
[`serialize`](@ref).

Types of values and bounds in constraints are specified explicitly in the
serialized representation; the mapping is specified by overloads of
[`deserialize_bound`](@ref) and [`deserialize_value`](@ref).
"""
function deserialize(::Type{Constraint}, x::Dict)
    value = deserialize_value(SerializationLabel{Symbol(x["value_type"])}, x["value"])
    bound = if "bound_type" in keys(x)
        deserialize_bound(SerializationLabel{Symbol(x["bound_type"])}, x["bound"])
    end
    return Constraint(value, bound)
end

"""
$(TYPEDSIGNATURES)

Deserialize a vector of 2 values into a [`Between`](@ref) bound.
"""
deserialize(::Type{Between}, x::Vector) =
    length(x) == 2 ? Between(x[1], x[2]) :
    throw(DomainError(x, "can not unserialize Between"))

"""
$(TYPEDSIGNATURES)

Deserialize a single value into an [`EqualTo`](@ref) bound.
"""
deserialize(::Type{EqualTo}, x::Float64) = EqualTo(x)

"""
$(TYPEDSIGNATURES)

Deserialize a dictionary with keys `idxs` and `weights` into a
[`LinearValue`](@ref).
"""
function deserialize(::Type{LinearValue}, x::Dict)
    idxs = Int.(x["idxs"])
    weights = Float64.(x["weights"])
    @assert length(idxs) == length(weights)
    for i = 1:(length(idxs)-1)
        @assert idxs[i] < idxs[i+1]
    end
    return LinearValue(; idxs, weights)
end

"""
$(TYPEDSIGNATURES)

Deserialize a dictionary with keys `idxs` and `weights` into a
[`LinearValue`](@ref). `idxs` must contain vectors of length 2 with the double
indices.
"""
function deserialize(::Type{QuadraticValue}, x::Dict)
    idxs = [(Int(v[1]), Int(v[2])) for v in x["idxs"] if length(v)==2 && v[1]<=v[2]]
    weights = Float64.(x["weights"])
    @assert length(idxs) == length(weights)
    for i = 1:(length(idxs)-1)
        @assert colex_lt(idxs[i], idxs[i+1])
    end
    return QuadraticValue(; idxs, weights)
end

#
# Serialization
#

"""
$(TYPEDSIGNATURES)

Convert a [`Tree`](@ref) into a "simple" representation that only consists of
basic Julia types.

In particular, all trees labeled as dictionaries with a single key `tree` that
indexes a dictionary of all keyed entries.
"""
serialize(x::Tree) = Dict("tree" => Dict(String(k) => serialize(v) for (k, v) in x))

"""
$(TYPEDSIGNATURES)

Convert a [`Constraint`](@ref) to basic Julia types.

The types of values and bounds are named explicitly to allow precise
deserialization without guessing; the values are found from overloads of
[`serialize_value_label`](@ref) and [`serialize_bound_label`](@ref). If the
bound is not present, the corresponding data is completely omitted and no label
is added.
"""
function serialize(x::Constraint)
    res = Dict(
        "value_type" => String(serialize_value_label(typeof(x.value))),
        "value" => serialize(x.value),
    )
    if !isnothing(x.bound)
        res["bound_type"] = String(serialize_bound_label(typeof(x.bound)))
        res["bound"] = serialize(x.bound)
    end
    return res
end

"""
$(TYPEDSIGNATURES)

Serialize a [`Between`](@ref) bound into a vector of the two interval
endpoints.
"""
serialize(x::Between) = [x.lower, x.upper]

"""
$(TYPEDSIGNATURES)

Serialize an [`EqualTo`](@ref) bound into a number.
"""
serialize(x::EqualTo) = x.equal_to

"""
$(TYPEDSIGNATURES)

Serialize a [`LinearValue`](@ref) into a dictionary with coefficient indices
and weights.
"""
serialize(x::LinearValue) = Dict("idxs" => x.idxs, "weights" => x.weights)

"""
$(TYPEDSIGNATURES)

Serialize a [`QuadraticValue`](@ref) into a dictionary with coefficient index
tuples and weights.
"""
serialize(x::QuadraticValue) =
    Dict("idxs" => [[i, j] for (i, j) in x.idxs], "weights" => x.weights)
