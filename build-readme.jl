# Weave readme
using Pkg
cd("c:/git/SortingLab/")
Pkg.activate("c:/git/SortingLab/readme-env")
Pkg.update()

using Weave

weave("README.jmd", out_path = :pwd, doctype = "github")

if false
    tangle("README.jmd")
end
