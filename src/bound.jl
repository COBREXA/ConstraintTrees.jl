
"""
$(TYPEDEF)

Convenience shortcut for "interval" bound; consisting of lower and upper bound
value.
"""
const IntervalBound = Tuple{Float64,Float64}

"""
$(TYPEDEF)

A special type of bound where the variable may only take on the values 0 or 1
exclusively.
"""
struct BinaryBound end

const Binary = BinaryBound()

"""
$(TYPEDEF)

A special type of bound where the variable may only take on integer values.
"""
struct IntegerBound end

const Integers = IntegerBound()

"""
$(TYPEDEF)

Shortcuts for possible bounds:

- either no bound is present (`nothing`),
- a single number is interpreted as an exact equality bound,
- a tuple of 2 numbers is interpreted as an interval bound,
- setting `BinaryBound()` or its alias, `Binary` creates an integer valued variable, that can only take on 0 or 1,
- setting `IntegerBound()` or its alias, `Integers` creates an integer valued variable.
"""
const Bound = Union{Nothing,Float64,IntervalBound,BinaryBound,IntegerBound}
