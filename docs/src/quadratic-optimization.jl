
# # Example: Quadratic optimization
#
# In this example we demonstrate the use of quadratic constraints and values.
# We assume that the reader is already familiar with the construction of
# `ConstraintTree`s; if not, it is advisable to read the previous part
# of the documentation first.
#
# In short, quadratic values and constraints are expressed similarly as other
# contents of the constraint trees using types `QValue` and
# `QConstraint`, which are quadratic alikes of the linear
# `Value` and `Constraint`.
#
# ## Working with quadratic values and constraints
#
# Algebraically, you can construct `QValue`s simply by multiplying the linear
# `Value`s:

import ConstraintTrees as C

system = C.variables(keys = [:x, :y, :z]);
qv = system.x.value * (system.y.value + 2 * system.z.value)

@test qv.idxs == [(1, 2), (1, 3)] #src
@test qv.weights == [1.0, 2.0] #src

# As with `Value`s, the `QValue`s can be easily combined, giving a nice way to
# specify e.g. weighted sums of squared errors with respect to various
# directions. Let's make a tiny helper first:
squared(x) = x * x

# Now, we can play with common representations of error values:
error_val =
    squared(system.x.value + system.y.value - 1) +
    squared(system.y.value + 5 * system.z.value - 3)

# This allows us to naturally express quadratic constraint (e.g., that an error
# must not be too big); and directly observe the error values in the system.
system = :vars^system * :error^C.QConstraint(qvalue = error_val, bound = (0.0, 100.0))

# Let's pretend someone has solved the system, and see how much "error" the
# solution has:
solution = [1.0, 2.0, -1.0];
st = C.solution_tree(system, solution);
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
ellipse_system = C.constraint_tree(
    :point => point,
    :in_area => C.QConstraint(
        qvalue = squared(point.x.value) / 4 + squared(10.0 - point.y.value),
        bound = (-Inf, 1.0),
    ),
);

# We now create another small system that constraints another point to stay on
# a line that crosses `(0, 0)` and `(1, 1)`. We could do this using a
# dot-product representation of line, but that would lead to issues later
# (mainly, the solver that we are planning to use only supports positive
# definite quadratic forms as constraints). Instead, let's use a
# single-variable-parametrized line equation.
line_param = C.variable().value;
line_system =
    :point^C.constraint_tree(
        :x => C.Constraint(value = 0 + 1 * line_param),
        :y => C.Constraint(value = 0 + 1 * line_param),
    );

# Finally, let's connect the systems using `+` operator and add the objective
# that would minimize the distance of the points:
s = :ellipse^ellipse_system + :line^line_system;

s *=
    :objective^C.QConstraint(
        qvalue = squared(s.ellipse.point.x.value - s.line.point.x.value) +
                 squared(s.ellipse.point.y.value - s.line.point.y.value),
    );
# (Note that if we used `*` to connect the systems, the variables from the
# definition of `point` would not be duplicated, and various non-interesting
# logic errors would follow.)

# ## Solving quadratic systems with JuMP
#
# To solve the above system, we need a matching solver that can work with
# quadratic constraints. Also, we need to create the function that translates
# the constraints into JuMP `Model`s to support the quadratic constraints.
import JuMP
function optimized_vars(cs::C.ConstraintTree, objective::Union{C.Value,C.QValue}, optimizer)
    model = JuMP.Model(optimizer)
    JuMP.@variable(model, x[1:C.var_count(cs)])
    if objective isa C.Value
        JuMP.@objective(model, JuMP.MAX_SENSE, C.value_product(objective, x))
    elseif objective isa C.QValue
        JuMP.@objective(model, JuMP.MAX_SENSE, C.qvalue_product(objective, x))
    end
    function add_constraint(c::C.Constraint)
        if c.bound isa Float64
            JuMP.@constraint(model, C.value_product(c.value, x) == c.bound)
        elseif c.bound isa Tuple{Float64,Float64}
            val = C.value_product(c.value, x)
            isinf(c.bound[1]) || JuMP.@constraint(model, val >= c.bound[1])
            isinf(c.bound[2]) || JuMP.@constraint(model, val <= c.bound[2])
        end
    end
    function add_constraint(c::C.QConstraint)
        if c.bound isa Float64
            JuMP.@constraint(model, C.qvalue_product(c.qvalue, x) == c.bound)
        elseif c.bound isa Tuple{Float64,Float64}
            val = C.qvalue_product(c.qvalue, x)
            isinf(c.bound[1]) || JuMP.@constraint(model, val >= c.bound[1])
            isinf(c.bound[2]) || JuMP.@constraint(model, val <= c.bound[2])
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

# We can now load a suitable optimizer and solve the system:
import Clarabel
st = C.solution_tree(s, optimized_vars(s, -s.objective.qvalue, Clarabel.Optimizer))

# If the optimization worked well, we can nicely get out the position of the
# closest point to the line that is in the elliptical area:
(st.ellipse.point.x, st.ellipse.point.y)

@test isapprox(st.ellipse.point.x, 1.7888553691812248, atol = 1e-3) #src
@test isapprox(st.ellipse.point.y, 9.552787347840578, atol = 1e-3) #src

# ...as well as the position on the line that is closest to the ellipse:
C.elems(st.line.point)

@test isapprox(st.line.point.x, st.line.point.y, atol = 1e-3) #src
@test isapprox(st.line.point.x, 5.670821358510901, atol = 1e-3) #src

# ...and, with a bit of extra math, the minimized distance -- originally we
# maximized the negative squared error, thus the negation and square root:
sqrt(st.objective)

@test isapprox(sqrt(st.objective), 5.489928950781118, atol = 1e-3) #src
