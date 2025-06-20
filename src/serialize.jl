
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

struct SerializationLabel{L} end

deserialize_bound(::Type{SerializationLabel{:between}}, x) = deserialize(Between, x)
deserialize_bound(::Type{SerializationLabel{:equal_to}}, x) = deserialize(EqualTo, x)

serialize_bound_label(::Type{Between}) = :between
serialize_bound_label(::Type{EqualTo}) = :equal_to

deserialize_value(::Type{SerializationLabel{:linear}}, x) = deserialize(LinearValue, x)
deserialize_value(::Type{SerializationLabel{:quadratic}}, x) =
    deserialize(QuadraticValue, x)

serialize_value_label(::Type{LinearValue}) = :linear
serialize_value_label(::Type{QuadraticValue}) = :quadratic

#
# Deserialization
#

deserialize(::Type{Tree{T}}, x::Dict) where {T} = Tree{T}(
    Symbol(k) => if v isa Dict && length(keys(v))==1 && first(keys(x))=="tree"
        deserialize(Tree{T}, v)
    else
        deserialize(T, v)
    end for (k, v) in x["tree"]
)

function deserialize(::Type{Constraint}, x::Dict)
    value = deserialize_value(SerializationLabel{Symbol(x["value_type"])}, x["value"])
    bound = if "bound_type" in keys(x)
        deserialize_bound(SerializationLabel{Symbol(x["bound_type"])}, x["bound"])
    end
    return Constraint(value, bound)
end

deserialize(::Type{Between}, x::Vector) =
    length(x) == 2 ? Between(x[1], x[2]) :
    throw(DomainError(x, "can not unserialize Between"))
deserialize(::Type{EqualTo}, x::Float64) = EqualTo(x)

function deserialize(::Type{LinearValue}, x::Dict)
    idxs = Int.(x["idxs"])
    weights = Float64.(x["weights"])
    @assert length(idxs) == length(weights)
    return LinearValue(; idxs, weights)
end

function deserialize(::Type{QuadraticValue}, x::Dict)
    idxs = [Tuple{Int,Int}(v[1], v[2]) for v in x["idxs"] if length(v)==2]
    weights = Float64.(x["weights"])
    @assert length(idxs) == length(weights)
    return QuadraticValue(; idxs, weights)
end

#
# Serialization
#

serialize(x::Tree) = Dict("tree" => Dict(String(k) => serialize(v) for (k, v) in x))

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

serialize(x::Between) = [x.lower, x.upper]
serialize(x::EqualTo) = x.equal_to

serialize(x::LinearValue) = Dict("idxs" => x.idxs, "weights" => x.weights)
serialize(x::QuadraticValue) =
    Dict("idxs" => [[i, j] for (i, j) in x.idxs], "weights" => x.weights)
