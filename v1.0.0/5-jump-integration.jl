
# Copyright (c) 2024, University of Luxembourg                             #src
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

# # Better integration with JuMP

# The examples in this documentation generally used the simple and
# straightforward method of converting the trees and values to JuMP system,
# which depends on algebraic operators working transparently with JuMP values
# within function [`substitute`](@ref ConstraintTrees.substitute).
#
# ## Substitution folding problem
#
# Despite the simplicity, this approach is sometimes sub-optimal, especially in
# cases when the result of the substitution is recalculated with added values.
# For example, in the naive case, JuMP is forced to successively build
# representations for all intermediate expressions with incomplete variables,
# until all variables are in place. In turn, this may very easily reach a
# quadratic computational complexity.
#
# More generally, any representation of substitution result that "does not
# `reduce()` easily" will suffer from this problem. A different (often
# specialized) approach is thus needed.
#
# ## Solution: Prevent successive folding
#
# For such cases, it is recommended to replace the `substitute` calls with a
# custom function that can interpret the required [`Value`](@ref
# ConstraintTrees.Value)s itself, and converts them without the overhead of
# creating temporary values.

import ConstraintTrees as C

# First, let's create a lot of variables, and a constraint that will usually
# trigger this problem (and a JuMP warning) if used with normal
# [`substitute`](@ref ConstraintTrees.substitute):

x = :vars^C.variables(keys = Symbol.("x$i" for i = 1:1000), bounds = C.Between(0, 10))
x *= :sum^C.Constraint(sum(C.value.(values(x.vars))))

# Now, imagine the expressions are represented e.g. by sparse vectors of fixed
# size (as common in linear-algebraic systems). We can produce the vectors
# efficiently as follows:

import SparseArrays: sparsevec
v = x.sum.value

value_in_a_vector = sparsevec(v.idxs, v.weights, 1000)

@test isapprox(sum(value_in_a_vector), 1000.0) #src

# This usually requires only a single memory allocation, and runs in time
# linear with the number of variables in the value. As an obvious downside, you
# need to implement this functionality for all kinds of [`Value`](@ref
# ConstraintTrees.Value)s you encounter.

# ## Solution for JuMP

# [`LinearValue`](@ref ConstraintTrees.LinearValue)s can be translated to
# JuMP's `AffExpr`s:

using JuMP, GLPK

function substitute_jump(val::C.LinearValue, vars)
    e = AffExpr() # unfortunately @expression(model, 0) is not type stable and gives an Int
    for (i, w) in zip(val.idxs, val.weights)
        if i == 0
            add_to_expression!(e, w)
        else
            add_to_expression!(e, w, vars[i])
        end
    end
    e
end

model = Model(GLPK.Optimizer)
@variable(model, V[1:1000])
jump_value = substitute_jump(x.sum.value, V)

@test length(jump_value.terms) == 1000 #src

# This function can be re-used in functions like `optimized_vars` as shown in
# other examples in the documentation.

# For [`QuadraticValue`](@ref ConstraintTrees.QuadraticValue)s, the same
# approach extends only with a minor modification:

function substitute_jump(val::C.QuadraticValue, vars)
    e = QuadExpr() # unfortunately @expression(model, 0) is not type stable and gives an Int
    for ((i, j), w) in zip(val.idxs, val.weights)
        if i == 0 && j == 0
            add_to_expression!(e, w)
        elseif i == 0 # the symmetric case is prohibited
            add_to_expression!(e, w, vars[j])
        else
            add_to_expression!(e, w, vars[i], vars[j])
        end
    end
    e
end

qvalue = 123 + (x.vars.x1.value + x.vars.x2.value) * (x.vars.x3.value - 321)
jump_qvalue = substitute_jump(qvalue, V)

@test length(jump_qvalue.terms) == 2 #src
@test length(jump_qvalue.aff.terms) == 2 #src
@test jump_qvalue.aff.constant == 123.0 #src
