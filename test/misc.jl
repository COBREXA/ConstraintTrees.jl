
import ConstraintTrees as C
import SparseArrays as SP

@testset "Values" begin
    x = C.Value(SP.sparse([5.0, 0, 6.0, 0])) + C.Value(idxs = [2, 3], weights = [5.0, 4.0])
    @test x.idxs == [1, 2, 3]
    @test x.weights == [5.0, 5.0, 10.0]
end

@testset "Constraint tree operations" begin
    ct1 = C.allocate_variables(keys = [:a, :b])
    ct2 = C.allocate_variables(keys = [:c, :d])

    @test collect(propertynames(ct1)) == [:a, :b]
    @test [k for (k, _) in ct2] == [:c, :d]
    @test eltype(ct2) == Pair{Symbol,C.ConstraintTreeElem}
    @test collect(keys((:x^ct1 * :x^ct2).x)) == [:a, :b, :c, :d]
    @test_throws ErrorException ct1 * ct1
    @test_throws ErrorException :a^ct1 * ct1
    @test_throws ErrorException ct1 * :a^ct1
end

@testset "Constraint tree operations" begin
    ct = C.allocate_variables(keys = [:a, :b])
    @test_throws BoundsError C.solution_tree(ct, [1.0])
    st = C.solution_tree(ct, [123.0, 321.0])
    @test st.a == 123.0
    @test st[:b] == 321.0
    @test collect(propertynames(st)) == [:a, :b]
    @test collect(keys(st)) == [:a, :b]
    @test sum([v for (_, v) in st]) == 444.0
    @test sum(values(st)) == 444.0
    @test eltype(st) == Pair{Symbol,C.SolutionTreeElem}
end
