__precompile__(true)
module SortingLab

# export sort, sort!
# package code goes here

using InternedStrings, StatsBase, CategoricalArrays

export fsortperm, radixsort, radixsort!, fsort, fsort!

include("radixsort.jl")
include("fsortperm.jl")
include("radixsort_interned.jl")
include("CategoricalArrays_sort.jl")
# include("../benchmarks/is_parallel_hist_faster_YES.jl")
end # module
