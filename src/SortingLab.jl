module SortingLab

# export sort, sort!
# package code goes here

export fsortperm, radixsort, radixsort!

include("radixsort.jl")
include("fsortperm.jl")
# include("../benchmarks/is_parallel_hist_faster_YES.jl")
end # module
