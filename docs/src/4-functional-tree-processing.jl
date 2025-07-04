
# Copyright (c) 2023-2024, University of Luxembourg                        #src
# Copyright (c) 2023, Heinrich-Heine University Duesseldorf                #src
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

# # Example: Processing the trees functionally
#
# The main goal of ConstraintTrees.jl is to make the constraint-manipulating
# code orderly and elegant, and preferably short. To improve the manipulation
# of large constraint trees, the package also provides a small
# functional-programming-inspired framework that allows one to easily
# transform, summarize and combine all kinds of trees without writing
# repetitive code.
#
# You might already seen the [`zip`](@ref ConstraintTrees.zip) function in the
# [metabolic modeling example](1-metabolic-modeling.md). There are more
# functions that behave like `zip`, so let's have a little summary here:
#
# - [`map`](@ref ConstraintTrees.map) applies a function to all elements
#   (including the nested ones) of a tree
# - [`mapreduce`](@ref ConstraintTrees.mapreduce) transforms all elements of a
#   tree using a given function (first parameter) and then combines the result
#   using the second function (a binary operator); [`reduce`](@ref
#   ConstraintTrees.reduce) is a shortcut where the `map` function is an
#   identity
# - [`zip`](@ref ConstraintTrees.zip) combines elements common to both trees
#   using a given zipping function
# - [`merge`](@ref ConstraintTrees.merge) combines all elements in both trees
#   (including the ones present in only one tree) using a given merging
#   function
# - [`variables_for`](@ref ConstraintTrees.variables_for) allocates a variable
#   for each constraint in the tree and allows the user to specify bounds
#
# Additionally, all these have their "indexed" variant which allows the user to
# know the path where the tree elements are being merged. The path is passed to
# the handling function as a tuple of symbols. The variants are prefixed with
# `i`:
#
# - [`imap`](@ref ConstraintTrees.imap)
# - [`imapreduce`](@ref ConstraintTrees.ireduce) (here the path refers to the
#   common directory of the reduced elements) together with the shortcut
#   [`ireduce`](@ref ConstraintTrees.ireduce)
# - [`izip`](@ref ConstraintTrees.izip)
# - [`imerge`](@ref ConstraintTrees.imerge)
# - [`variables_ifor`](@ref ConstraintTrees.variables_ifor)

#md # !!! danger "Naming conflicts with Julia base"
#md #     Names of some of the higher-order function conflict with Julia base package and are not compatible. We recommend using them with named imports, such as by `import ConstraintTrees as C` and then `C.zip` and `C.merge`.

# For demonstration, let's make a very simple constrained system.

import ConstraintTrees as C

constraints = :point^C.variables(keys = [:x, :y], bounds = C.Between(0, 1))

C.pretty(constraints)

# ## Transforming trees with `map`
#
# Let's make a tree where the bounds are 2 times bigger and negated:

x = C.map(constraints) do x
    C.Constraint(x.value, -2 * x.bound)
end

C.pretty(x)

@test x.point.x.bound.lower == -2.0 #src

# With `imap`, we can detect that we are working on a specific constraint and
# do something entirely different:

x = C.imap(constraints) do path, x
    if path == (:point, :x)
        C.Constraint(x.value, 100 * x.bound)
    else
        x
    end
end

C.pretty(x)

@test x.point.x.bound.upper == 100 #src

# ## Summarizing the trees with `mapreduce` and `reduce`
#
# How many constraints are there in the tree?

x = C.mapreduce(init = 0, _ -> 1, +, constraints)

@test x == 2 #src

# What if we want to sum all constraints' values?

x = C.reduce(constraints, init = C.Constraint(zero(C.LinearValue))) do x, y
    C.Constraint(value = x.value + y.value)
end

@test x.value.idxs == [1, 2] #src
@test x.value.weights == [1.0, 1.0] #src

# What if we want to reduce the `point` specially?

x = C.ireduce(constraints, init = C.Constraint(zero(C.LinearValue))) do path, x, y
    return C.Constraint(value = x.value + y.value) #src
    if path == (:point,)
        println("reducing in point/ subtree: $(x.value) + $(y.value)")
    end
    C.Constraint(value = x.value + y.value)
end;

#

x

# ## Comparing trees with `zip`

# Assume we have two solutions of the constraint system above, as follows:

s1 = C.substitute_values(constraints, [0.9, 0.8])
s2 = C.substitute_values(constraints, [0.99, 0.78])

# Let's compute the squared distance between individual items:

x = C.zip(s1, s2, Float64) do x, y
    (x - y)^2
end

C.pretty(x)

@test isapprox(x.point.x, 0.09^2) #src

# What if we want to put extra weight on distances between specific variables?

x = C.izip(s1, s2, Float64) do path, x, y
    if path == (:point, :x)
        10
    else
        1
    end * (x - y)^2
end

C.pretty(x)

@test isapprox(x.point.x, 10 * 0.09^2) #src
@test C.reduce(&, C.izip((_, a, _, c) -> a == c, s1, s2, s1, Bool), init = true) #src

# ## Combining trees with `merge`
#
# Zipping trees together always produces a tree that only contains the intersection
# of keys from both original trees. That is not very useful if one wants to
# e.g. add new elements from extended trees. `merge`-style functions implement
# precisely that.
#
# The "zipping" function in `merge` takes 2 arguments; any of these may be
# `missing` in case one of the trees does not contain the elements. Also, a key
# may be omitted by returning `missing` from the function.
#
# Let's make some very heterogeneous trees and try to combine them:

t1 = :x^s1.point * :y^s2.point;
t2 = :x^s2.point * :z^s1.point;
t3 = :y^s2.point;

# As a nice combination function, we can try to compute an average on all
# positions from the first 2 trees:

t = C.merge(t1, t2, Float64) do x, y
    ismissing(x) && return y
    ismissing(y) && return x
    (x + y) / 2
end

C.pretty(t)

@test isapprox(t.x.x, 0.945) #src
@test isapprox(t.x.y, 0.79) #src

# Merge can also take 3 parameters (which is convenient in some situations). We
# may also want to omit certain output completely:

tz = C.merge(t1, t2, t3, Float64) do x, y, z
    ismissing(z) && return missing
    ismissing(x) && return y
    ismissing(y) && return x
    (x + y) / 2
end

C.pretty(tz)

@test isapprox(tz.y.x, 0.99) #src
@test isapprox(tz.y.y, 0.78) #src

# We also have the indexed variants; for example this allows us to only merge
# the `x` elements in points:

tx = C.imerge(t1, t2, Float64) do path, x, y
    last(path) == :x || return missing
    ismissing(x) && return y
    ismissing(y) && return x
    (x + y) / 2
end

C.pretty(tx)

@test tx.y.x == tz.y.x #src

# For completeness, we demonstrate a trick with easily coalescing the "missing"
# things to compute the means more easily:

miss(_::Missing, _, def) = def;
miss(x, f, _) = f(x);
fixmean(a) = miss(a, x -> (x, 1), (0, 0));

tx = C.imerge(t1, t2, t3, Float64) do path, x, y, z
    last(path) == :x || return missing
    tmp = fixmean.([x, y, z])
    sum(first.(tmp)) / sum(last.(tmp))
end

C.pretty(tx)

@test isapprox(tx.y.x, 0.99) #src
@test !haskey(tx.y, :y) #src
@test get(() -> 123, tx.x, :y) == 123 #src

# ## Allocating trees of variables using `variables_for`
#
# In many cases it is convenient to make a new model from the old by allocating
# new variables for whatever "old" tree out there. For example, one might wish
# to allocate a new variable for an approximate value (plus-minus-one) for each
# of the above tree's values. `variables_for` allocates one variable for each
# element of the given tree, and allows you to create bounds for the variables
# via the given function:

C.pretty(t)

#

x = C.variables_for(t) do a
    C.Between(a - 1, a + 1)
end

C.pretty(x)

@test C.variable_count(x) == 6 #src
@test isapprox(x.x.x.bound.lower, -0.055) #src

# (Note that the variable indexes in subtrees are now different from each
# other!)

# As in all cases with indexes, you may match the tree path to do a special
# action. For example, to make sure that all `y` coordinates are exact in the
# new system:

x = C.variables_ifor(t) do path, a
    if last(path) == :y
        C.EqualTo(a)
    else
        C.Between(a - 1, a + 1)
    end
end

C.pretty(x)

@test isapprox(x.x.x.bound.upper, 1.945) #src
@test isapprox(x.x.y.bound.equal_to, 0.79) #src

# ## Looping through the trees with `traverse`
#
# Since we are writing our code in an imperative language, it is often quite
# beneficial to run a function over the trees just for the side effect.
#
# For this purpose, [`traverse`](@ref ConstraintTrees.traverse) and
# [`itraverse`](@ref ConstraintTrees.itraverse) work precisely like
# [`map`](@ref ConstraintTrees.map) and [`imap`](@ref ConstraintTrees.imap),
# except no tree is returned and the only "output" of the functions are their
# side effect.
#
# For example, you can write a less-functional counting of number of
# constraints in the tree as follows:

constraint_count = 0
C.traverse(x) do _
    global constraint_count += 1
end
constraint_count

@test constraint_count == 6 #src

# The indexed variant of traverse works as expected; it may be beneficial e.g.
# for printing the contents of the constraint trees in a "flat" form, or
# potentially working with other path-respecting data structures.

C.itraverse(x) do ix, c
    path = join(String.(ix), '/')
    return #src
    println("$path = $c")
end;

# To prevent uncertainty, both functions always traverse the keys in sorted
# order.

# ## Removing constraints with `filter`
#
# In many cases it is beneficial to simplify the constraint system by
# systematically removing constraints. [`filter`](@ref ConstraintTrees.filter)
# and [`ifilter`](@ref ConstraintTrees.ifilter) run a function on all subtrees
# and leaves (usually the leaves are [`Constraint`](@ref
# ConstraintTrees.Constraint)s), and only retain these where the function
# returns `true`.
#
# For example, this removes all constraints named `y`:

filtered = C.ifilter(x) do ix, c
    return c isa C.ConstraintTree || last(ix) != :y
end

C.pretty(filtered)

@test !haskey(filtered.x, :y) #src

# Functions [`filter_leaves`](@ref ConstraintTrees.filter_leaves) and
# [`ifilter_leaves`](@ref ConstraintTrees.ifilter_leaves) act similarly but
# automatically assume that the directory structure is going to stay intact,
# freeing the user from having to handle the subdirectories.
#
# The above example thus simplifies to:

filtered = C.ifilter_leaves(x) do ix, c
    last(ix) != :y
end

C.pretty(filtered)

@test !haskey(filtered.x, :y) #src

# We can also remove whole variable ranges:

filtered = C.filter_leaves(x) do c
    all(>=(4), c.value.idxs)
end

C.pretty(filtered)

# ### Pruning unused variable references
#
# Filtering operations may leave the constraint tree in a slightly sub-optimal
# state, where there are indexes allocated for variables that are no longer
# used!

C.variable_count(filtered)

# To investigate, it is possible to calculate a "reference count" for each
# variable:

variable_ref_counts = zeros(Int, C.variable_count(filtered))
C.collect_variables!(filtered) do idx
    if idx > 0
        variable_ref_counts[idx] += 1
    end
end
variable_ref_counts

# To fix the issue, it is possible to "squash" the variable indexes using
# [`prune_variables`](@ref ConstraintTrees.prune_variables):

pruned = C.prune_variables(filtered)

C.variable_count(pruned)

@test C.variable_count(pruned) == 3 #src

# Note that after the pruning and renumbering, the involved constraint trees
# are no longer compatible, and should not be combined with `*`. As an
# anti-example, one might be interested in pruning the variable values before
# joining them in to larger constraint tree, e.g. to simplify larger quadratic
# values:

pruned_qv = C.prune_variables(x.y.x.value * x.z.y.value)

# This value now corresponds to a completely different value in the original
# tree! Compare:

(pruned_qv, x.y.x.value * x.z.y.value)

@test C.variable_count(pruned_qv) == 2 #src
@test pruned_qv.idxs == (x.x.x.value * x.x.y.value).idxs #src
@test pruned_qv.weights == (x.x.x.value * x.x.y.value).weights #src

# As another common source of redundant variable references, some variables may
# be used with zero weights. This situation is not detected by
# [`prune_variables`](@ref ConstraintTrees.prune_variables) by default, but you
# can remove the "zeroed out" variable references by using
# [`drop_zeros`](@ref ConstraintTrees.drop_zeros), which allows the pruning to
# work properly.
#
# For example, the value constructed in the tree below does not really refer to
# `x.x.y` anymore, but pruning does not help to get rid of the now-redundant
# variable:

x.x.y.value = x.x.y.value + x.x.x.value * x.x.x.value - x.x.y.value

#

C.variable_count(C.prune_variables(x))

@test C.variable_count(C.prune_variables(x)) == 6 #src

# After the zero-weight variable references are dropped, the pruning behaves as
# desired:

C.variable_count(C.prune_variables(C.drop_zeros(x)))

@test C.variable_count(C.prune_variables(C.drop_zeros(x))) == 5 #src

# ## Converting to and from vector representations
#
# Often it is useful to look at the constraint system via the "matrix" view as
# common in mathematical optimization. Functions [`deflate`](@ref
# ConstraintTrees.deflate) and [`reinflate`](@ref ConstraintTrees.reinflate)
# provide a sensible way to convert the trees into vectors of constraints and
# back, giving more possibilities to work with the tree contents.
#
# In particular, trees that only contain linear values may be represented as
# matrices. For demonstration, one may convert the following (slightly fixed)
# tree to a matrix, a vector of lower and upper bounds, and a vector of
# constraint "row" names:

x.x.y.value = 3*x.x.x.value + 2 * x.y.y.value + 0.5 * x.z.x.value
C.pretty(x)

# `deflate` serves as a conversion tool to vectors:

C.deflate(x, C.MaybeBound) do c
    c.bound
end

# To extract a proper matrix, one has to convert the linear values to actual
# vectors:

import SparseArrays: sparse, sparsevec, SparseVector

n_vars = C.variable_count(x)
vecs = C.deflate(x, SparseVector{Float64}) do c
    sparsevec(c.value.idxs, c.value.weights, n_vars)
end;
sparse(hcat(vecs...)')

# Finally, to extract everything at once with proper identifiers, it is useful
# to use [`ideflate`](@ref ConstraintTrees.ideflate):
rows = C.ideflate(x, Pair) do i, c
    join(i, "/") => (sparsevec(c.value.idxs, c.value.weights, n_vars), c.bound)
end;

# To convert to the usual form, we use some helper functions:
lb(x::C.EqualTo) = x.equal_to
ub(x::C.EqualTo) = x.equal_to
lb(x::C.Between) = x.lower
ub(x::C.Between) = x.upper

# This gives good row "identifiers":
row_names = first.(rows)
# ...as well as lower and upper bound vectors:
row_bounds = let constraints = last.(last.(rows))
    (lb.(constraints), ub.(constraints))
end
# ...and the "linear programming" matrix:
matrix = sparse(hcat(first.(last.(rows))...)')

@test size(matrix) == (6, 6) #src
@test isapprox(sum(matrix), 10.5) #src

# The vector data can be re-inserted into "same-shaped" trees. For example, one
# can make a tree where variable references sum to 1 for each variable:
weighted_matrix = matrix ./ max.(eps(), sum(matrix, dims = 1))

# The weighted matrix is then converted to a vector and re-inserted:
C.reinflate(x, C.LinearValue.(sparse.(eachrow(weighted_matrix)))) |> C.pretty
