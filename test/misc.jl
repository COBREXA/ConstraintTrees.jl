
import ConstraintTrees as C
import SparseArrays as SP

@testset "Values" begin
    x =
        C.LinearValue(SP.sparse([5.0, 0, 6.0, 0])) +
        C.LinearValue(idxs = [2, 3], weights = [5.0, 4.0])
    @test x.idxs == [1, 2, 3]
    @test x.weights == [5.0, 5.0, 10.0]
    x = convert(C.LinearValue, 123.0)
    @test x.idxs == [0]
    @test x.weights == [123.0]
end

@testset "QValues" begin
    @test (
        1 - (
            1 *
            (1 + (zero(C.LinearValue) - zero(C.QuadraticValue) + zero(C.LinearValue)) + 1) *
            1
        ) + convert(C.QuadraticValue, 123.0)
    ).idxs == [(0, 0)]
    @test convert(C.QuadraticValue, C.variable().value).idxs == [(0, 1)]
    x =
        C.LinearValue(SP.sparse(Float64[])) +
        C.QuadraticValue(SP.sparse([1.0 0 1; 0 0 3; 1 0 0])) -
        C.LinearValue(SP.sparse([1.0, 2.0])) - 1.0
    @test x.idxs == [(0, 0), (0, 1), (1, 1), (0, 2), (1, 3), (2, 3)]
    @test x.weights == [-1.0, -1.0, 2.0, -2.0, 2.0, 3.0]
    @test C.QuadraticValue(1.0).idxs == [(0, 0)]
    @test C.QuadraticValue(C.LinearValue(1.0)).idxs == [(0, 0)]
end

@testset "Constraints" begin
    @test C.bound(C.variable(bound = 123.0)) == 123.0
    @test C.value(C.variable(bound = 123.0)).idxs == [1]
    @test C.bound(2 * -convert(C.Constraint, (C.variable(bound = 123.0))) / 2) == -123.0

    x = C.variable().value
    s = :a^C.Constraint(x) + :b^C.Constraint(x * x - x)
    @test C.value(s.a).idxs == [1]
    @test C.value(s.b).idxs == [(0, 2), (2, 2)]
end

@testset "Constraint tree operations" begin
    ct1 = C.variables(keys = [:a, :b])
    ct2 = C.variables(keys = [:c, :d])

    @test isempty(C.ConstraintTree())
    @test !isempty(ct1)
    @test haskey(ct1, :a)
    @test hasproperty(ct1, :a)
    @test !haskey(ct1, :c)
    @test !hasproperty(ct1, :c)

    @test collect(propertynames(ct1)) == [:a, :b]
    @test [k for (k, _) in ct2] == [:c, :d]
    @test (keytype(ct2), valtype(ct2)) == (Symbol, C.ConstraintTreeElem)
    @test collect(keys((:x^ct1 * :x^ct2).x)) == [:a, :b, :c, :d]
    @test_throws ErrorException ct1 * ct1
    @test_throws ErrorException :a^ct1 * ct1
    @test_throws ErrorException ct1 * :a^ct1
end

@testset "Solution tree operations" begin
    ct = C.variables(keys = [:a, :b])

    @test_throws BoundsError C.SolutionTree(ct, [1.0])
    st = C.SolutionTree(ct, [123.0, 321.0])

    @test isempty(C.SolutionTree())
    @test isempty(C.SolutionTree(C.ConstraintTree(), Float64[]))
    @test !isempty(st)
    @test haskey(st, :a)
    @test hasproperty(st, :a)
    @test !haskey(st, :c)
    @test !hasproperty(st, :c)

    @test length(ct) == length(st)
    @test st.a == 123.0
    @test merge(+, st, st).a == 246.0
    @test st[:b] == 321.0
    @test collect(propertynames(st)) == [:a, :b]
    @test collect(keys(st)) == [:a, :b]
    @test sum([v for (_, v) in st]) == 444.0
    @test sum(values(st)) == 444.0
    @test eltype(st) == Pair{Symbol,C.ValueTreeElem}
end
