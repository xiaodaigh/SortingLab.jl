__precompile__(true)
module SortingLab

# export sort, sort!
# package code goes here

#using InternedStrings, StatsBase, CategoricalArrays

# import InternedStrings
import StatsBase: countmap
import CategoricalArrays: CategoricalArray
import Base.Threads: @threads

export fsortperm, radixsort, radixsort!, fsort, fsort!


include("fsortperm.jl")
include("sorttwo!.jl")
include("uint_hist.jl")
include("uint_map.jl")
include("radixsort_string.jl")
include("fsortperm_string.jl")
include("fsortperm_Integer.jl")
include("fsort_CategoricalArrays.jl")
include("fsort.jl")
include("fsort-missing.jl")
# include("radixsort-StrFs.jl")
# include("../benchmarks/is_parallel_hist_faster_YES.jl")
end # module
