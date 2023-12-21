
import ConstraintTrees
using Test

@testset "ConstraintTrees tests" begin
    @testset "Metabolic modeling" begin
        include("../docs/src/1-metabolic-modeling.jl")
    end

    @testset "Quadratic optimization" begin
        include("../docs/src/2-quadratic-optimization.jl")
    end

    @testset "Mixed-integer optimization" begin
        include("../docs/src/3-mixed-integer-optimization.jl")
    end

    @testset "Miscellaneous methods" begin
        include("misc.jl")
    end
end
