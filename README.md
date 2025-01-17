
# ConstraintTrees.jl -- Tidy constraints for optimization problems

| Build status | Documentation |
|:---:|:---:|
| [![CI](https://github.com/COBREXA/ConstraintTrees.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/COBREXA/ConstraintTrees.jl/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/COBREXA/ConstraintTrees.jl/branch/master/graph/badge.svg?token=A2ui7exGIH)](https://codecov.io/gh/COBREXA/ConstraintTrees.jl) | [![stable documentation](https://img.shields.io/badge/docs-stable-blue)](https://cobrexa.github.io/ConstraintTrees.jl/stable) [![dev documentation](https://img.shields.io/badge/docs-dev-cyan)](https://cobrexa.github.io/ConstraintTrees.jl/dev) |

Package `ConstraintTrees.jl` provides a simple data structure `ConstraintTree`
for organizing the contents of various constrained optimization problems. As a
main goal, it abstracts over the distinction between constraints and variables,
allowing much tidier, nicer and extensible representation of many kinds of
complex constraint systems. The primary purpose is to support constraint-based
metabolic modeling within
[COBREXA.jl](https://github.com/COBREXA/COBREXA.jl).

ConstraintTrees are intended to be used with
[JuMP](https://github.com/jump-dev/JuMP.jl), but the package does not depend on
JuMP -- instead it is completely generic and lightweight, and may be used with
any other constraint-solving framework. The documentation describes a typical
use of ConstraintTrees for describing and solving constrained linear (LP),
quadratic (QP) and mixed-integer (MILP) problems using JuMP, together with
copy-pasteable code snippets that provide the integration.

ConstraintTrees package is actively maintained and open for extensions. Feel
free to discuss changes and ideas via issues and pull requests.

#### Acknowledgements

`ConstraintTrees.jl` was developed at the Luxembourg Centre for Systems
Biomedicine of the University of Luxembourg
([uni.lu/lcsb](https://www.uni.lu/lcsb))
and at Institute for Quantitative and Theoretical Biology at Heinrich Heine
University Düsseldorf ([qtb.hhu.de](https://www.qtb.hhu.de/en/)).
The development was supported by European Union's Horizon 2020 Programme under
PerMedCoE project ([permedcoe.eu](https://www.permedcoe.eu/)),
agreement no. 951773.

<img src="docs/src/assets/unilu.svg" alt="Uni.lu logo" height="64px">   <img src="docs/src/assets/lcsb.svg" alt="LCSB logo" height="64px">   <img src="docs/src/assets/hhu.svg" alt="HHU logo" height="64px" style="height:64px; width:auto">   <img src="docs/src/assets/qtb.svg" alt="QTB logo" height="64px" style="height:64px; width:auto">   <img src="docs/src/assets/permedcoe.svg" alt="PerMedCoE logo" height="64px">
