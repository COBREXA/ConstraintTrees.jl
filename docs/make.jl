using Documenter, Literate, ConstraintTrees

examples =
    sort(filter(x -> endswith(x, ".jl"), readdir(joinpath(@__DIR__, "src"), join = true)))

for example in examples
    Literate.markdown(
        example,
        joinpath(@__DIR__, "src"),
        repo_root_url = "https://github.com/COBREXA/ConstraintTrees.jl/blob/master",
    )
end

example_mds = first.(splitext.(basename.(examples))) .* ".md"

withenv("COLUMNS" => 150) do
    makedocs(
        modules = [ConstraintTrees],
        clean = false,
        format = Documenter.HTML(
            ansicolor = true,
            canonical = "https://cobrexa.github.io/ConstraintTrees.jl/stable/",
        ),
        sitename = "ConstraintTrees.jl",
        linkcheck = false,
        pages = ["README" => "index.md"; example_mds; "Reference" => "reference.md"],
        strict = [:missing_docs, :cross_references, :example_block],
    )
end

deploydocs(
    repo = "github.com/COBREXA/ConstraintTrees.jl.git",
    target = "build",
    branch = "gh-pages",
    push_preview = false,
)
