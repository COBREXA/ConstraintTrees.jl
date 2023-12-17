
# # Example: Mixed integer optimization
#
# In this example we demonstrate the use of binary, and integer valued
# variables. We assume that the reader is already familiar with the construction
# of `ConstraintTree`s; if not, it is advisable to read the previous part of the
# documentation first.

# The simple problem we will solve is:
# max    x + y + 3 z
# s. t.
#        x + 2 y + z   <= 5
#        x +   y       >= 1
#        x, y binary
#        z integer

import ConstraintTrees as C

system = C.variables(keys = [:x, :y, :z], bounds=[C.Binary,C.Binary,C.Integers])

system *= :objective^C.Constraint(system[:x].value + system[:y].value + 3 * system[:z].value)

system *= :binary_constraints^C.ConstraintTree(
    :constraint1 => C.Constraint(system[:x].value + 2 * system[:y].value + system[:z].value, (0, 5)),
    :constraint2 => C.Constraint(system[:x].value + system[:y].value, (1, Inf))
)

# ## Solving MILP systems with JuMP
#
# To solve the above system, we need a matching solver that can work with binary
# and integer constraints. Also, we need to slightly modify the function that
# translates the constraints into JuMP `Model`s to support the integer
# constraints.

import JuMP
function optimized_vars(
    cs::C.ConstraintTree,
    objective::C.LinearValue,
    optimizer,
)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
    JuMP.@objective(model, JuMP.MAX_SENSE, C.substitute(objective, x))
    function add_constraint(c::C.Constraint)
        b = c.bound
        if b isa Tuple{Float64,Float64}
            val = C.substitute(c.value, x)
            isinf(b[1]) || JuMP.@constraint(model, val >= b[1])
            isinf(b[2]) || JuMP.@constraint(model, val <= b[2])
        elseif b isa C.BinaryBound
            # val = C.substitute(c.value, x) # TODO, returns a AffExpr which is incompatible with set_binary
            JuMP.set_binary.(x[c.value.idxs])
        elseif b isa C.IntegerBound
            JuMP.set_integer.(x[c.value.idxs])    
        end
    end
    function add_constraint(c::C.ConstraintTree)
        add_constraint.(values(c))
    end
    add_constraint(cs)
    JuMP.set_silent(model)
    JuMP.optimize!(model)
    JuMP.value.(model[:x])
end

# We can now load a suitable optimizer (MILP solver) and solve the system by
# maximizing the objective:
import GLPK
solution = C.constraint_values(system, optimized_vars(system, system.objective.value, GLPK.Optimizer))

# Thus, we can see that the optimal objective is:
solution.objective

# With values for the variables:
(solution.x, solution.y, solution.z)

@test isapprox(solution.x, 1, atol = 1e-2) #src
@test isapprox(solution.y, 0, atol = 1e-2) #src
@test isapprox(solution.z, 4, atol = 1e-2) #src
