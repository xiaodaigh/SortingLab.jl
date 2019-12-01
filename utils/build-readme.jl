using Pkg; Pkg.activate("c:/git/SortingLab")

using Weave

weave("c:/git/SortingLab/README.jmd", out_path="c:/git/SortingLab/", doctype="github")
