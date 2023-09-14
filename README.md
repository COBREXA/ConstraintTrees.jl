
# ConstraintTrees.jl -- Tidy constraints for linear programming

| Build status | Documentation |
|:---:|:---:|
| ![CI status](https://github.com/COBREXA/ConstraintTrees.jl/workflows/CI/badge.svg?branch=master) [![codecov](https://codecov.io/gh/COBREXA/ConstraintTrees.jl/branch/master/graph/badge.svg?token=A2ui7exGIH)](https://codecov.io/gh/COBREXA/ConstraintTrees.jl) | [![stable documentation](https://img.shields.io/badge/docs-stable-blue)](https://cobrexa.github.io/ConstraintTrees.jl/stable) [![dev documentation](https://img.shields.io/badge/docs-dev-cyan)](https://cobrexa.github.io/ConstraintTrees.jl/dev) |

Package `ConstraintTrees.jl` provides a simple data structure `ConstraintTree`
for organizing the contents of linear constrained optimization problems. As a
main goal, it abstracts over the distinction between constraints and variables,
allowing much tidier representation for many kinds of complex constraint
systems. The primary purpose is to support constraint-based metabolic modeling
within [COBREXA.jl](https://github.com/LCSB-BioCore/COBREXA.jl).

`ConstraintTrees.jl` is new and under active development. Feel free to discuss
the changes and ideas.

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
