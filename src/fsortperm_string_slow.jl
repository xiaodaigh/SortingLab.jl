import SortingAlgorithms: uint_mapping
import Base.Ordering
# sorts vs using radix sort but skip the last few bits as defined by skipbits
function sort32!(vs::AbstractVector{T}, lo::Int=1, hi::Int=length(vs), o::Ordering=Base.Forward, ts=similar(vs); skipbits = 32, RADIX_SIZE = 11, RADIX_MASK = 0x000007ff) where T
    # Input checking
    if lo >= hi;  return vs;  end

    # Make sure we're sorting a bits type
    # T = Base.Order.ordtype(o, vs)

    # Init
    iters = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    bin = zeros(UInt32, 2^RADIX_SIZE, iters)
    if lo > 1;  bin[1,:] = lo-1;  end

    # Histogram for each element, radix
    for i = lo:hi
        v = uint_mapping(o, vs[i])
        for j = skipbits÷RADIX_SIZE+1:iters
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            @inbounds bin[idx,j] += 1
        end
    end

    # Sort!
    swaps = 0
    len = hi-lo+1
    for j = skipbits÷RADIX_SIZE+1:iters
        # Unroll first data iteration, check for degenerate case
        v = uint_mapping(o, vs[hi])
        idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1

        # are all values the same at this radix?
        if bin[idx,j] == len;  continue;  end

        cbin = cumsum(bin[:,j])
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
            vs[i] = ts[i]
        end
    end
    vs
end

function load_uint2(s::String, skipbytes)
    ss = sizeof(s)
    if skipbytes > ss
        return UInt(0)
    elseif skipbytes + 4 > ss
        s1 = ((s |> pointer |> Ptr{UInt32}) + skipbytes) |> unsafe_load
        s2 = Base.zext_int(UInt64, s1) |> ntoh 
        extra_bits_to_shift = 8(skipbytes + 4 - ss)
        return (s2 >> (32+extra_bits_to_shift)) << (32+extra_bits_to_shift)
    else
        s1 = ((s |> pointer |> Ptr{UInt32}) + skipbytes) |> unsafe_load
        return Base.zext_int(UInt64, s1) |> ntoh 
    end
end

# this version is smaller
function fsortperm2(svec::AbstractVector{String})
    strlen = maximum(sizeof, svec)
    strlen = max(strlen-4, 0)
    underly_bits = load_uint2.(svec, strlen) .| collect(UInt32(1):UInt32(length(svec)))
    underly_bits = sort32!(underly_bits, 1, length(underly_bits),  Base.Forward)
    ss = (underly_bits .<< 32) .>> 32
 
    while strlen > 0
        strlen = max(strlen-4, 0)
        underly_bits = load_uint2.(@view(svec[ss]), strlen) .| ss
        underly_bits = sort32!(underly_bits, 1, length(underly_bits),  Base.Forward)
        ss = (underly_bits .<< 32) .>> 32
    end
    return ss
end

# too slow
function fsortperm4(svec::AbstractVector{String}, ::Type{T} = UInt) where T<:Unsigned
    strlen = maximum(sizeof, svec)
    strlen = max(strlen-sizeof(T), 0)

    l = length(svec)

    pairs = collect(enumerate(svec))
    
    sort!(pairs, by=x->load_uint(T, x[2], strlen), alg = RadixSort)

    while strlen > 0
        strlen = max(strlen-sizeof(T), 0)
        sort!(pairs, by=x->load_uint(T, x[2], strlen), alg = RadixSort)
    end
    return [x[1] for x in pairs]
end

# sort pointer but need to keep sizeof, so a bit slow
function fsortperm6(svec::AbstractVector{String}, ::Type{T} = UInt) where T<:Unsigned
    strlen = maximum(sizeof, svec)
    strlen = max(strlen-sizeof(T), 0)

    l = length(svec)

    pairs = Vector{Tuple{T, Int, Ptr{UInt}}}(l)
    for (i, svec1) = enumerate(svec)
        pairs[i] = tuple(i, sizeof(svec1), pointer(svec1) |> Ptr{UInt})
    end

    sort!(pairs, by=x->load_uint(x[3],x[2],strlen), alg = RadixSort)

    while strlen > 0
        strlen = max(strlen-sizeof(T), 0)
        sort!(pairs, by=x->load_uint(x[3],x[2],strlen), alg = RadixSort)
    end
    return [x[1] for x in pairs]
end