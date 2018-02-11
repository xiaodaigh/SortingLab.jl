function fsort!(vs::Vector{T}, lo::Int = 1, hi::Int=length(vs); RADIX_SIZE = 11, RADIX_MASK::UInt32 = 0x07ff) where T <:Union{BaseRadixSortSafeTypes}
    # Input checking
    if lo >= hi;  return vs;  end

    o = Forward

    # Init
    iters = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    # number of buckets in the counting step
    nbuckets = 2^RADIX_SIZE
    
    # Histogram for each element, radix
    bin = uint_hist(vs, RADIX_SIZE, RADIX_MASK)

    # bin = zeros(UInt32, nbuckets, iters)
    # if lo > 1;  bin[1,:] = lo-1;  end

    # Sort!
    swaps = 0
    len = hi-lo+1

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
        cbin[idx] -= 1

        # Finish the loop...
        @inbounds for i in hi-1:-1:lo
            v = uint_mapping(o, vs[i])
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            ci = cbin[idx]
            ts[ci] = vs[i]
            cbin[idx] -= 1
        end
        vs,ts = ts,vs
        swaps += 1
    end

    if isodd(swaps)
        vs,ts = ts,vs
        
        for i = lo:hi
            @inbounds vs[i] = ts[i]
        end
    end
    vs
end

fsort(vs, radix_opts = (11, 0x07ff)) = fsort!(copy(vs), RADIX_SIZE = radix_opts[1], RADIX_MASK = radix_opts[2])