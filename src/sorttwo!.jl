import StatsBase: BaseRadixSortSafeTypes

"""
    sorttwo!(vs, index)

Sort both the `vs` and reorder `index` at the same. This allows for faster sortperm
for radix sort.
"""
function sorttwo!(vs::AbstractVector{T}, index, lo::Int = 1, hi::Int=length(vs), RADIX_SIZE = 16, RADIX_MASK = 0xffff) where T # <:Union{BaseRadixSortSafeTypes}
    # Input checking
    if lo >= hi;  return (vs, index);  end
    #println(vs)
    o = Forward

    # Init
    iters = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    # number of buckets in the counting steuint_histp
    nbuckets = 2^RADIX_SIZE

    # Histogram for each element, radix
    bin = uint_hist(vs, RADIX_SIZE, RADIX_MASK)

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
        idx = Int((v >> ((j-1)*RADIX_SIZE)) & RADIX_MASK) + 1

        # are all values the same at this radix?
        if bin[idx,j] == len;  continue;  end

        # cbin = cumsum(bin[:,j])
        # tries to achieve the above one-liner with more efficiency
        cbin = zeros(UInt32, nbuckets)
        cbin[1] = bin[1,j]
        @inbounds for i in 2:nbuckets
            cbin[i] = cbin[i-1] + bin[i,j]
        end

        ci = cbin[idx]
        #println((ci, hi))
        ts[ci] = vs[hi]
        index1[ci] = index[hi]
        # println(cbin[idx])
        cbin[idx] -= 1

        # Finish the loop...        
        @inbounds for i in hi-1:-1:lo
            v = uint_mapping(o, vs[i])
            idx = Int((v >> ((j-1)*RADIX_SIZE)) & RADIX_MASK) + 1
            ci = cbin[idx]
            #println(ci)
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
