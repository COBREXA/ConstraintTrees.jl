
# # Example: Quadratic optimization
#
# In this example we demonstrate the use of quadratic constraints and values.
# We assume that the reader is already familiar with the construction of
# `ConstraintTree`s; if not, it is advisable to read the previous part
# of the documentation first.
#
# In short, quadratic values and constraints are expressed similarly as other
# contents of the constraint trees using type `QuadraticValue`, which is
# basically an affine-quadratic alike of the affine-linear `LinearValue`.
#
# ## Working with quadratic values and constraints
#
# Algebraically, you can construct `QuadraticValue`s simply by multiplying the
# linear `LinearValue`s:

import ConstraintTrees as C

system = C.variables(keys = [:x, :y, :z])
qv = system.x.value * (system.y.value + 2 * system.z.value)

@test qv.idxs == [(1, 2), (1, 3)] #src
@test qv.weights == [1.0, 2.0] #src

# As with `LinearValue`s, the `QuadraticValue`s can be easily combined, giving
# a nice way to specify e.g. weighted sums of squared errors with respect to
# various directions. We can thus represent common formulas for error values:
error_val =
    C.squared(system.x.value + system.y.value - 1) +
    C.squared(system.y.value + 5 * system.z.value - 3)

# This allows us to naturally express quadratic constraint (e.g., that an error
# must not be too big); and directly observe the error values in the system.
system = :vars^system * :error^C.Constraint(error_val, (0, 100))

# (For simplicity, you can also use the `Constraint` constructor to make
# quadratic constraints out of `QuadraticValue`s -- it will overload properly.)

# Let's pretend someone has solved the system, and see how much "error" the
# solution has:
solution = [1.0, 2.0, -1.0]
st = C.constraint_values(system, solution)
st.error

# ...not bad for a first guess.

# ## Building quadratic systems
#
# Let's create a small quadratic system that finds the closest distance between
# an ellipse and a line and let some of the conic solvers available in JuMP
# solve it. First, let's make a representation of a point in 2D:
point = C.variables(keys = [:x, :y])

# We can create a small system that constraints the point to stay within a
# simple elliptical area centered around `(0.0, 10.0)`:
ellipse_system = C.ConstraintTree(
    :point => point,
    :in_area => C.Constraint(
        C.squared(point.x.value) / 4 + C.squared(10.0 - point.y.value),
        (-Inf, 1.0),
    ),
)

# We now create another small system that constraints another point to stay on
# a line that crosses `(0, 0)` and `(2, 1)`. We could do this using a
# dot-product representation of line, but that would lead to issues later
# (mainly, the solver that we are planning to use only supports positive
# definite quadratic forms as constraints). Instead, let's use a
# single-variable-parametrized line equation.
line_param = C.variable().value
line_system =
    :point^C.ConstraintTree(
        :x => C.Constraint(0 + 2 * line_param),
        :y => C.Constraint(0 + 1 * line_param),
    )

# Finally, let's connect the systems using `+` operator and add the objective
# that would minimize the distance of the points:
s = :ellipse^ellipse_system + :line^line_system

s *=
    :objective^C.Constraint(
        C.squared(s.ellipse.point.x.value - s.line.point.x.value) +
        C.squared(s.ellipse.point.y.value - s.line.point.y.value),
    )
# (Note that if we used `*` to connect the systems, the variables from the
# definition of `point` would not be duplicated, and various non-interesting
# logic errors would follow.)

# ## Solving quadratic systems with JuMP
#
# To solve the above system, we need a matching solver that can work with
# quadratic constraints. Also, we need to slightly generalize the function that
# translates the constraints into JuMP `Model`s to support the quadratic
# constraints.
import JuMP
function optimized_vars(
    cs::C.ConstraintTree,
    objective::Union{C.LinearValue,C.QuadraticValue},
    optimizer,
)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
    JuMP.@objective(model, JuMP.MAX_SENSE, C.substitute(objective, x))
    function add_constraint(c::C.Constraint)
        b = c.bound
        if b isa Float64
            JuMP.@constraint(model, C.substitute(c.value, x) == b)
        elseif b isa Tuple{Float64,Float64}
            val = C.substitute(c.value, x)
            isinf(b[1]) || JuMP.@constraint(model, val >= b[1])
            isinf(b[2]) || JuMP.@constraint(model, val <= b[2])
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

# We can now load a suitable optimizer and solve the system by maximizing the
# negative squared error:
import Clarabel
st = C.constraint_values(s, optimized_vars(s, -s.objective.value, Clarabel.Optimizer))

# If the optimization worked well, we can nicely get out the position of the
# closest point to the line that is in the elliptical area:
(st.ellipse.point.x, st.ellipse.point.y)

@test isapprox(st.ellipse.point.x, 1.414, atol = 1e-2) #src
@test isapprox(st.ellipse.point.y, 9.293, atol = 1e-2) #src

# ...as well as the position on the line that is closest to the ellipse:
st.line.point

@test isapprox(st.line.point.x, 2 * st.line.point.y, atol = 1e-3) #src
@test isapprox(st.line.point.x, 4.849, atol = 1e-2) #src

# ...and, with a little bit of extra math, the minimized distance:
sqrt(st.objective)

@test isapprox(sqrt(st.objective), 7.679, atol = 1e-2) #src
