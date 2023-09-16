
import ConstraintTrees as C
import SparseArrays as SP

@testset "Values" begin
    x = C.Value(SP.sparse([5.0, 0, 6.0, 0])) + C.Value(idxs = [2, 3], weights = [5.0, 4.0])
    @test x.idxs == [1, 2, 3]
    @test x.weights == [5.0, 5.0, 10.0]
    x = convert(C.Value, 123.0)
    @test x.idxs == [0]
    @test x.weights == [123.0]
end

@testset "QValues" begin
    @test (
        1 - (1 * (1 + (zero(C.Value) - zero(C.QValue) + zero(C.Value)) + 1) * 1) +
        convert(C.QValue, 123.0)
    ).idxs == [(0, 0)]
    @test convert(C.QValue, C.variable().value).idxs == [(0, 1)]
    x =
        C.Value(SP.sparse(Float64[])) + C.QValue(SP.sparse([1.0 0 1; 0 0 3; 1 0 0])) -
        C.Value(SP.sparse([1.0, 2.0])) - 1.0
    @test x.idxs == [(0, 0), (0, 1), (1, 1), (0, 2), (1, 3), (2, 3)]
    @test x.weights == [-1.0, -1.0, 2.0, -2.0, 2.0, 3.0]
    @test C.QValue(1.0).idxs == [(0, 0)]
    @test C.QValue(C.Value(1.0)).idxs == [(0, 0)]
end

@testset "Constraints" begin
    @test C.bound(C.variable(bound = 123.0)) == 123.0
    @test C.value(C.variable(bound = 123.0)).idxs == [1]
    @test C.bound(2 * -convert(C.QConstraint, (C.variable(bound = 123.0))) / 2) == -123.0

    x = C.variable().value
    s = :a^C.Constraint(value = x) + :b^C.QConstraint(qvalue = x * x - x)
    @test C.value(s.a).idxs == [1]
    @test C.value(s.b).idxs == [(0, 2), (2, 2)]
end

@testset "Constraint tree operations" begin
    ct1 = C.variables(keys = [:a, :b])
    ct2 = C.variables(keys = [:c, :d])

    @test collect(propertynames(ct1)) == [:a, :b]
    @test [k for (k, _) in ct2] == [:c, :d]
    @test eltype(ct2) == Pair{Symbol,C.ConstraintTreeElem}
    @test collect(keys((:x^ct1 * :x^ct2).x)) == [:a, :b, :c, :d]
    @test_throws ErrorException ct1 * ct1
    @test_throws ErrorException :a^ct1 * ct1
    @test_throws ErrorException ct1 * :a^ct1
end

@testset "Solution tree operations" begin
    ct = C.variables(keys = [:a, :b])
    @test_throws BoundsError C.SolutionTree(ct, [1.0])
    st = C.SolutionTree(ct, [123.0, 321.0])
    @test st.a == 123.0
    @test st[:b] == 321.0
    @test collect(propertynames(st)) == [:a, :b]
    @test collect(keys(st)) == [:a, :b]
    @test sum([v for (_, v) in st]) == 444.0
    @test sum(values(st)) == 444.0
    @test eltype(st) == Pair{Symbol,C.SolutionTreeElem}
end
