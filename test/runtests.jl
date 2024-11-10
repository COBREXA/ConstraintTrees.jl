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

    @testset "Functional tree processing" begin
        include("../docs/src/4-functional-tree-processing.jl")
    end

    @testset "JuMP integration improvements" begin
        include("../docs/src/5-jump-integration.jl")
    end

    @testset "Miscellaneous methods" begin
        include("misc.jl")
    end
end
