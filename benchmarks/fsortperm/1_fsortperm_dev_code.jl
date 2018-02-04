################################################################################
# setting up
################################################################################
const VT = Pair{UInt32,UInt32}
const VTV = Vector{VT}

################################################################################
# Straight counting sort
################################################################################
function sortperm_int_range2(a, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = Vector{Int}(la)
    @inbounds for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1
        res[c] = i
    end

    res
end

################################################################################
# Hybrid MSD and counting sort
# I have shown below that coutning sorts beats radix sort up to 2^11= 2048 unique values
# so it makes sense to create a better one
################################################################################
function fsortperm_msd_hybrid(a, rangelen, minval, RADIX_SIZE;  sortcutoff = -1)
    # println(RADIX_SIZE," ", now())
    @assert 2^32 > rangelen
    @assert 2^32 >= length(a)
    vs = Vector{VT}(length(a))
    @inbounds for i in eachindex(a)
        vs[i] = Pair(UInt32(i),UInt32(a[i]))
    end
    # @time @inbounds vs = [Pair(UInt32(i),UInt32(ai)) for (i, ai) in enumerate(a)]

    iters = Int(ceil(log(2, rangelen)/RADIX_SIZE))
    # @assert iters <= ceil(Integer, sizeof(typeof(vs[1].second))*8/RADIX_SIZE)

    _fsortperm_msd_hybrid(vs, 1, length(vs), rangelen, minval, RADIX_SIZE, iters, sortcutoff = sortcutoff)
end

function _fsortperm_msd_hybrid(vs, lo, hi, rangelen, minval, RADIX_SIZE, iters, ts = similar(vs); sortcutoff = -1)
    len = hi-lo+1
    if len  == 1
        return [Int(vs[lo].first)]
    elseif rangelen <= sortcutoff || len <= sortcutoff
        # println("iters $iters lo:hi $(lo:hi) rangelen $rangelen minval $minval")
        av = [a1.second for a1 in vs[lo:hi]]
        # println("extrema $(extrema(Int.(av)))")
        if lo == 3026 && hi == 4037
            # @show av
            throw(error())
        end
        av_sortperm = sortperm_int_range2(av, rangelen, minval)
        # @show av_sortperm
        # issorted([Int(vs[j+lo-1].second) for j in av_sortperm])
        res = [Int(vs[j+lo-1].first) for j in av_sortperm]
        # println("ok2")
        return res
    end

    RADIX_MASK = UInt32(1<<RADIX_SIZE-1)
    
    # Init
    bin = zeros(UInt32, 2^RADIX_SIZE)

    # Histogram for each element, radix
    @inbounds for i = lo:hi
        v = vs[i].second - minval
        idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1
        @inbounds bin[idx] += 1
    end

    # Sort!

    # check for degenerate case
    v = vs[hi].second - minval
    idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1

    # are all values the same at this radix?
    # if bin[idx,iters] == len;  continue;  end
    if bin[idx] == len
        if iters == 1
            return [Int(vsi.first) for vsi in vs[lo:hi]] 
        else
            return _fsortperm_msd_hybrid(vs, lo, hi, rangelen, minval, RADIX_SIZE, iters-1, ts, sortcutoff = sortcutoff)
        end
    end

    # cbin = cumsum(bin[:])
    cbin  = copy(bin)
    cumsum!(bin, bin)
    cumsumbin = copy(bin)
    
    # copy the elements to the temporary array first
    @inbounds for i in lo:hi
        ts[i] = vs[i]
    end

    # now assign to original in the right order
    @inbounds for i in lo:hi
        v = ts[i].second - minval
        idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1
        ci = bin[idx]
        vs[lo - 1 + ci] = ts[i]
        bin[idx] -= 1
    end
    
    if iters == 1
        return [Int(vsi.first) for vsi in vs[lo:hi]]
    end

    # now that it's finished sorting sort each chunk recursive now
    res = Vector{Int}(length(vs))
    start_now = 1
    new_rangelen = 2^((iters-1)*RADIX_SIZE)
    # if false
    #     i = 1
    #     lo = 1
    #     hi = cumsumbin[1]
    #     rangelen = new_rangelen
    #     minval = 1
    #     iters = 1

    #     i = 2
    #     lo = cumsumbin[1] + 1
    #     hi = cumsumbin[2]
    #     hi |> Int
    #     minval = 1+(i-1)new_rangelen

    #     i = 4
    #     lo = cumsumbin[i-1] + 1
    #     hi = cumsumbin[3]
    #     hi |> Int
    #     minval = 1+(i-1)new_rangelen
    #     iters = 1
    # end

    for i = 1:length(cumsumbin)
        if cbin[i] != 0
            # println("iters $iters ith count $i")
            new_minval = minval+(i-1)new_rangelen
            res[start_now:cumsumbin[i]] = _fsortperm_msd_hybrid(vs, start_now + lo - 1, cumsumbin[i] + lo - 1, new_rangelen, new_minval, RADIX_SIZE, iters-1, ts, sortcutoff = sortcutoff)
            start_now = cumsumbin[i] + 1
            # println("Ok")
        end
    end
    res
end

################################################################################
# sorting algorithms from discourse
# https://discourse.julialang.org/t/ironic-observation-about-sort-and-sortperm-speed-for-small-intergers-vs-r/8715/20?u=xiaodai
################################################################################
# a = rand(1:1_000_000, 100_000_000)

function sortperm_int_range_p1(a, rangelen, minval, RADIX_SIZE)
    # println(RADIX_SIZE," ", now())
    @assert 2^32 > rangelen
    @assert 2^32 >= length(a)
    @time vs::VTV = Vector{VT}(length(a))
    @time @inbounds for i in eachindex(a)
        vs[i] = Pair(UInt32(i),UInt32(a[i]))
    end
    # @time @inbounds vs = [Pair(UInt32(i),UInt32(ai)) for (i, ai) in enumerate(a)]
    _sortperm_int_range_p1(vs, rangelen, minval, RADIX_SIZE)
end

function _sortperm_int_range_p1(vs, rangelen, minval, RADIX_SIZE)
    RADIX_MASK = UInt32(1<<RADIX_SIZE-1)
    ts = similar(vs)

    # Init
    lo = 1
    hi = length(vs)
    iters = Int(ceil(log(2, rangelen)/RADIX_SIZE))
    
    # println("iters: $iters")
    @assert iters <= ceil(Integer, sizeof(typeof(vs[1].second))*8/RADIX_SIZE)
    bin = zeros(UInt32, 2^RADIX_SIZE, iters)

    # Histogram for each element, radix
    @inbounds for i = lo:hi
        v = vs[i].second
        for j = 1:iters
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            @inbounds bin[idx,j] += 1
        end
    end

    # Sort!
    swaps = 0
    len = hi-lo+1
    @inbounds for j = 1:iters
        # Unroll first data iteration, check for degenerate case
        v = vs[hi].second
        idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1

        # are all values the same at this radix?
        if bin[idx,j] == len;  continue;  end

        cbin = cumsum(bin[:,j])
        ci = cbin[idx]
        ts[ci] = vs[hi]
        cbin[idx] -= 1

        # Finish the loop...
        @inbounds for i in hi-1:-1:lo
            v = vs[i].second
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
        @inbounds for i = lo:hi
            vs[i] = ts[i]
        end
    end
    res = Vector{Int}(length(vs))
    @inbounds for i in eachindex(vs)
        res[i] = Int(vs[i].first)
    end
    res
    # [Int(vs1.first) for vs1 in vs]
end