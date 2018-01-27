module SortingLab

# export sort, sort!
# package code goes here

using InternedStrings, StatsBase

export fsortperm, radixsort, radixsort!

include("radixsort.jl")
include("fsortperm.jl")
include("radixsort_interned.jl")
# include("../benchmarks/is_parallel_hist_faster_YES.jl")
end # module
