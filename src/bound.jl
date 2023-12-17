
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

Shortcut for possible bounds: either no bound is present (`nothing`), or a
single number is interpreted as an exact equality bound, or a tuple of 2
numbers is interpreted as an interval bound.
"""
const Bound = Union{Nothing,Float64,IntervalBound,BinaryBound}
