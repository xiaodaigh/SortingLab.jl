

using Base.Threads, SortingAlgorithms

import SortingAlgorithms: StringRadixSort, StringRadixSortAlg, uint_mapping, load_bits
import StatsBase: BaseRadixSortSafeTypes
import Base: Forward, ForwardOrdering, ReverseOrdering, sort!, Reverse


# winner from benchmarks/which_is_the_fastest_UInt_histogram.jl
function uint_hist(bits::Vector{T}) where T <: Unsigned
    iter = sizeof(T)÷2
    hist = zeros(UInt32, 65536, iter, nthreads())
    @threads for j = 1:length(bits)
        for i = 0:iter-1
            @inbounds hist[1+Int((bits[j] >> (i << 4)) & 0xffff), i+1, threadid()] += 1
        end
    end
    @threads for j in 1:iter
        for i = 2:nthreads()
            @inbounds hist[:, j, 1] .+= hist[:, j, i]
        end
    end
    hist[:,:,1]
end

# sort it by using sorttwo! on the pointer
function sort_1fasterhistogram!(svec::Vector{String}, lo::Int, hi::Int, ::StringRadixSortAlg, o::O) where O <: Union{ForwardOrdering, ReverseOrdering}
    if lo >= hi;  return svec;  end
    # the length subarray to sort
    l = hi - lo + 1

    # find the maximum string length    
    lens = maximum(sizeof, svec)
    skipbytes = lens
    # ptrs = pointer.(svec)
    if lens > 0
        while lens > 4
            skipbytes = max(0, skipbytes - 8)
            bits64 = zeros(UInt64, l)
            if o == Reverse
                bits64[lo:hi] .= .~load_bits.(UInt64, @view(svec[lo:hi]), skipbytes)
                SortingLab.sorttwo!(bits64, svec, lo, hi)
            else
                bits64[lo:hi] .= load_bits.(UInt64, @view(svec[lo:hi]), skipbytes)
                SortingLab.sorttwo!(bits64, svec, lo, hi)
            end
            lens -= 8
        end
        if lens > 0
            skipbytes = max(0, skipbytes - 4)
            bits32 = zeros(UInt32, l)
            if o == Reverse
                bits32[lo:hi] .= .~load_bits.(UInt32, @view(svec[lo:hi]), skipbytes)
                SortingLab.sorttwo!(bits32, svec, lo, hi)
            else
                bits32[lo:hi] .= load_bits.(UInt32, @view(svec[lo:hi]), skipbytes)
                SortingLab.sorttwo!(bits32, svec, lo, hi)
            end
            lens -= 4
        end
    end
    # unsafe_pointer_to_objref.(ptrs - 8)
    svec
end

"""
    sorttwo!(vs, index)

Sort both the `vs` and reorder `index` at the same. This allows for faster sortperm
for radix sort.
"""
function sorttwo!(vs::Vector{T}, index, lo::Int = 1, hi::Int=length(vs), RADIX_SIZE = 16, RADIX_MASK = 0xffff) where T <:BaseRadixSortSafeTypes
    # Input checking
    if lo >= hi;  return (vs, index);  end

    o = Forward

    # Init
    iters = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    # number of buckets in the counting step
    nbuckets = 2^RADIX_SIZE
    
    # Histogram for each element, radix
    bin = uint_hist(vs)

    # bin = zeros(UInt32, nbuckets, iters)
    # if lo > 1;  bin[1,:] = lo-1;  end

    # Sort!
    swaps = 0
    len = hi-lo+1

    index1 = similar(index)
    ts=similar(vs)
    for j = 1:iters
        # Unroll first data iteration, check for degenerate case
        v = uint_mapping(o, vs[hi])
        idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1

        # are all values the same at this radix?
        if bin[idx,j] == len;  continue;  end

        # cbin = cumsum(bin[:,j])
        # tries to achieve the above one-liner with more efficiency
        cbin = zeros(UInt32, nbuckets)
        cbin[1] = bin[1,j]
        for i in 2:nbuckets
            cbin[i] = cbin[i-1] + bin[i,j]
        end

        ci = cbin[idx]
        ts[ci] = vs[hi]
        index1[ci] = index[hi]
        cbin[idx] -= 1

        # Finish the loop...
        @inbounds for i in hi-1:-1:lo
            v = uint_mapping(o, vs[i])
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            ci = cbin[idx]
            ts[ci] = vs[i]
            index1[ci] = index[i]
            cbin[idx] -= 1
        end
        vs,ts = ts,vs
        index, index1 = index1, index
        swaps += 1
    end

    if isodd(swaps)
        vs,ts = ts,vs
        index, index1 = index1, index
        for i = lo:hi
            @inbounds vs[i] = ts[i]
            @inbounds index[i] = index1[i]
        end
    end
    (vs, index)
end


using SortingLab
using Base.Test
using SortingAlgorithms
import SortingAlgorithms: load_bits

# write your own tests here
# @test 1 == 2
N = 100_000_000
K = 100
samplespace = "id".*dec.(1:N÷K,10);
srand(1)
svec = rand(samplespace, N);

using BenchmarkTools



# overall sorting is faster too
function ghi(svec)
    csvec = copy(svec)
    gc()
    @time a = @elapsed sort_1fasterhistogram!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)

    csvec = copy(svec)
    gc()
    @time b = @elapsed SortingAlgorithms.sort!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)
    a,b
end
@time [ghi(svec) for i=repeat([4], outer=5)]