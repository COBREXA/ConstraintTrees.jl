
import ConstraintTrees
using Test

@testset "ConstraintTrees tests" begin
    @testset "Metabolic modeling" begin
        include("../docs/src/metabolic-modeling.jl")
    end

    @testset "Miscellaneous methods" begin
        include("misc.jl")
    end
end
