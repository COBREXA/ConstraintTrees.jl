
# Copyright (c) 2023-2024, University of Luxembourg
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ConstraintTrees as C
import SparseArrays as SP

@testset "Values" begin
    x =
        C.LinearValue(SP.sparse([5.0, 0, 6.0, 0])) +
        C.LinearValue(idxs = [2, 3], weights = [5.0, 4.0])
    @test x.idxs == [1, 2, 3]
    @test x.weights == [5.0, 5.0, 10.0]
    @test C.substitute_values(x, [1, 2, 3, 4]) == C.substitute(x, [1, 2, 3, 4])
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
    @test C.bound(C.variable(bound = 123.0)).equal_to == 123.0
    @test C.value(C.variable(bound = 123.0)).idxs == [1]
    @test C.bound(-convert(C.Constraint, (C.variable(bound = 123.0))) * 2 / 2).equal_to ==
          -123.0
    @test let x = C.bound(-convert(C.Constraint, (C.variable(bound = (-1, 2))) * 2 / 2))
        (x.lower, x.upper) == (-2.0, 1.0)
    end

    x = C.variable().value
    s = :a^C.Constraint(x, 5.0) + :b^C.Constraint(x * x - x, (4.0, 6.0))
    @test C.value(s.a).idxs == [1]
    @test C.value(s.b).idxs == [(0, 2), (2, 2)]
    @test C.value(s.a.value) === C.value(s.a)
    vars = [C.LinearValue([1], [1.0]), C.LinearValue([2], [1.0])]
    @test C.substitute(s.a, vars).bound == s.a.bound
    @test C.substitute(s.a, vars).value.idxs == s.a.value.idxs
    @test C.substitute(s.a, vars).value.weights == s.a.value.weights
    @test C.substitute(s.b, vars).bound == s.b.bound
    @test C.substitute(s.b, vars).value.idxs == s.b.value.idxs
    @test C.substitute(s.b, vars).value.weights == s.b.value.weights
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
    @test haskey(ct1, "a")

    @test collect(propertynames(ct1)) == [:a, :b]
    @test [k for (k, _) in ct2] == [:c, :d]
    @test (keytype(ct2), valtype(ct2)) == (Symbol, C.ConstraintTreeElem)
    @test collect(keys((:x^ct1 * :x^ct2).x)) == [:a, :b, :c, :d]
    @test_throws ErrorException ct1 * ct1
    @test_throws ErrorException :a^ct1 * ct1
    @test_throws ErrorException ct1 * :a^ct1
    @test C.var_count(C.variables_for(_ -> C.EqualTo(0.0), ct1 + ct2)) == 4

    delete!(ct1, "a")
    ct2["a"] = ct1["b"]
    @test !haskey(ct1, :a)
    @test haskey(ct2, :a)
end

@testset "Solution tree operations" begin
    ct = C.variables(keys = [:a, :b])

    @test_throws BoundsError C.substitute_values(ct, [1.0])
    st = C.substitute_values(ct, [123.0, 321.0])

    @test isempty(C.substitute_values(C.ConstraintTree(), Float64[]))
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
    @test eltype(st) == Pair{Symbol,Union{C.Tree{Float64},Float64}}
end

@testset "Pretty-printing" begin
    ct = C.variables(keys = [:a, :b])
    ct = :x^ct + :y^ct

    iob(f, args...) = begin
        iob = IOBuffer()
        f(iob, args...)
        String(take!(iob))
    end

    s(x) = iob(show, MIME"text/plain"(), x)

    @test length(C.ADWrap(ct)) == length(ct)
    @test occursin(":x", s(ct))
    @test occursin(":y", s(ct))
    @test occursin(r"Tree{[a-zA-Z.]*Constraint}", s(ct))
    @test occursin("2 elements", s(ct.x))
    @test occursin(":a", s(ct.x))
    @test occursin("[2]", s(ct.x.b))
    @test occursin("[1.0]", s(ct.x.a))

    p(x) = iob(C.pretty, x)
    @test p(zero(C.LinearValue)) == "0"
    @test p(zero(C.QuadraticValue)) == "0"
end
