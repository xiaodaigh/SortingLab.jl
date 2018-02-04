__precompile__(true)
module SortingLab

# export sort, sort!
# package code goes here

using InternedStrings, StatsBase, CategoricalArrays, ShortStrings

export fsortperm, radixsort, radixsort!, fsort, fsort!

include("radixsort_string.jl")
include("fsortperm_string.jl")
include("fsortperm_Integer.jl")
include("radixsort.jl")
# include("radixsort_interned.jl")
include("fsort_CategoricalArrays.jl")
# include("../benchmarks/is_parallel_hist_faster_YES.jl")
end # module
