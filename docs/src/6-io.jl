
# Copyright (c) 2025, University of Luxembourg                             #src
#                                                                          #src
# Licensed under the Apache License, Version 2.0 (the "License");          #src
# you may not use this file except in compliance with the License.         #src
# You may obtain a copy of the License at                                  #src
#                                                                          #src
#     http://www.apache.org/licenses/LICENSE-2.0                           #src
#                                                                          #src
# Unless required by applicable law or agreed to in writing, software      #src
# distributed under the License is distributed on an "AS IS" BASIS,        #src
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #src
# See the License for the specific language governing permissions and      #src
# limitations under the License.                                           #src

# # Exporting and importing constraint systems
#
# To ease communication with other software, it is possible to export
# constraint trees to a file and re-import them. That may serve various
# purposes:
#
# - you can exchange the systems in constraint trees more easily than by
#   sharing the "builder" scripts, and more reliably and portably than with
#   Julia's general serialization capabilities (in package `Serialization`)
# - you can exchange the system with different software (and different
#   programming environments) which may e.g. implement other solving and
#   analysis methods
# - you may separate your software into a tree-building and tree-solving part,
#   both more lightweight and more suitable to use in resource-constrained
#   environments (such as on HPCs).
#
# The package exports functions [`serialize`](@ref ConstraintTrees.serialize)
# and [`deserialize`](@ref ConstraintTrees.deserialize) that convert the
# constraint trees to and from Julia containers (dictionaries and vectors that
# only contain simple data such as strings and numbers). These can be further
# converted to JSON or other data exchange formats.
#
# For demonstration, we are going to make a simple constraint tree:

import ConstraintTrees as C

t = C.variables(keys = [:x, :y], bounds = C.Between(-10, 10))
t *=
    :difference^C.Constraint(t.x.value - t.y.value, C.EqualTo(3)) *
    :length^C.Constraint(C.squared(t.x.value) + C.squared(t.y.value))

# In the "nice formatting" the tree looks as follows:
C.pretty(t)

# ## Serialization

# Serialization converts the tree to a Dict with appropriate contents:

C.serialize(t)

# The arguably easiest way to "export" the file is to convert it to JSON:

import JSON
JSON.print(C.serialize(t), 2)

# ...and with appropriate functions, save the JSON to disk:
open("ct-test.json", "w") do f
    JSON.print(f, C.serialize(t))
end

# ## De-serialization

# Because of the involved polymorphism, deserialization functions need to know
# the type of what is actually being parsed. With that in hand, the JSON can be
# re-loaded as follows, giving the same tree:

t2 = C.deserialize(C.ConstraintTree, JSON.parsefile("ct-test.json"))

C.pretty(t2)
