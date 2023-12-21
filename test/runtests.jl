
import ConstraintTrees
using Test

@testset "ConstraintTrees tests" begin
    @testset "Metabolic modeling" begin
        include("../docs/src/metabolic-modeling.jl")
    end

    @testset "Quadratic optimization" begin
        include("../docs/src/quadratic-optimization.jl")
    end

    @testset "Mixed-integer optimization" begin
        include("../docs/src/mixed-integer-optimization.jl")
    end

    @testset "Miscellaneous methods" begin
        include("misc.jl")
    end
end
