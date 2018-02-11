using SortingAlgorithms
import SortingAlgorithms: uint_mapping
import Base.Ordering

function load_uint(::Type{T}, s::String, skipbytes) where T <: Unsigned
    ss = sizeof(s)
    if skipbytes > ss
        return T(0)
    elseif skipbytes + sizeof(T) > ss
        s1 = ((s |> pointer |> Ptr{T}) + skipbytes) |> unsafe_load |> ntoh
        extra_bits_to_shift = 8(skipbytes + sizeof(T) - ss)
        return (s1 >> extra_bits_to_shift) << extra_bits_to_shift
    else
        return s1 = ((s |> pointer |> Ptr{T}) + skipbytes) |> unsafe_load |> ntoh
    end
end

load_uint(s::String, skipbytes) = load_uint(UInt, s, skipbytes)

function load_uint(sptr::Ptr{T}, ss, skipbytes) where T <: Unsigned
    if skipbytes > ss
        return T(0)
    elseif skipbytes + sizeof(T) > ss
        s1 = ((sptr |> Ptr{T}) + skipbytes) |> unsafe_load |> ntoh
        extra_bits_to_shift = 8(skipbytes + sizeof(T) - ss)
        return (s1 >> extra_bits_to_shift) << extra_bits_to_shift
    else
        return s1 = ((sptr |> Ptr{T}) + skipbytes) |> unsafe_load |> ntoh
    end
end


# function load_uint_shift(s::String, skipbytes)
#     s1 = ((((s |> pointer |> Ptr{UInt64}) + skipbytes) |> unsafe_load) << 32) >> 32
#     Base.zext_int(UInt64, s1) |> ntoh
# end

# timing is similar
# @time load_uint.(svec, 4);
# @time load_uint_shift.(svec, 4);

# @time radixsort(svec); #20
# @time sort!(svec, by = x -> load_uint(x, 4)); #61

# @time svec_sorted = radixsort(svec);
# print(issorted(svec_sorted))

"""
    fsortperm(svec)

Faster sortperm for string vectors
"""
function fsortperm(svec::AbstractVector{String}, ::Type{T} = UInt) where T<:Unsigned
    strlen = maximum(sizeof, svec)
    strlen = max(strlen-sizeof(T), 0)

    l = length(svec)

    pairs = Vector{Tuple{T, UInt32}}(l)
    for (i, svec1) = enumerate(svec)
        pairs[i] = tuple(load_uint(T, svec1, strlen), i)
    end

    sort!(pairs, by=x->x[1], alg = RadixSort)

    while strlen > 0
        strlen = max(strlen-sizeof(T), 0)

        for (i, p) in enumerate(pairs)
            p2 = p[2]
            pairs[i] = tuple(load_uint(T, svec[p2], strlen), p2)
        end

        sort!(pairs, by=x->x[1], alg = RadixSort)
    end
    return [x[2] for x in pairs]
end


# function fsortperm3(svec::AbstractVector{String}, ::Type{T} = UInt) where T<:Unsigned
#     strlen = maximum(sizeof, svec)
#     strlen = max(strlen-sizeof(T), 0)

#     l = length(svec)

#     pairs = Vector{Pair{T, UInt32}}(l)
#     for (i, svec1) = enumerate(svec)
#         pairs[i] = Pair(load_uint(T, svec1, strlen), i)
#     end

#     sort!(pairs, by=x->x.first, alg = RadixSort)

#     while strlen > 0
#         strlen = max(strlen-4, 0)

#         for (i, svec1) = enumerate(svec)
#             pairs[i] = Pair(load_uint(T, svec1, strlen), pairs[2][2])
#         end
#         sort!(pairs, by=x->x.first, alg = RadixSort)
#     end
#     return [x.second for x in pairs]
# end


function testing()
    using SortingAlgorithms, SortingLab, ShortStrings
    import SortingLab: load_uint
    ss = "id".*dec.(1:100,3);
    svec = rand(ss, 100_000_000);
    @time x = fsortperm(svec);
    issorted(svec[x])

    @time ssvec = ShorterString.(svec)
    @time sort(ssvec, by = x->x.size_content, alg=RadixSort)
    @time String.(ssvec)


    ss = randstring.(rand(1:32,1_000_000))
    svec = rand(ss, 1_000_000)
    @time x = fsortperm(svec);
    issorted(svec[x])


    ss = "id".*dec.(1:1_000_000, 10)
    svec = rand(ss, 100_000_000)
    gc()
    # gc_enable(false)
    @time x = fsortperm(svec);
    # gc_enable(true)
    issorted(svec[x])

    meh(s) = reinterpret(UInt, pointer(s))
    meh2(s) = UInt(pointer(s))

    @time meh.(svec)
    @time pointer.(svec)
    @time x = fsortperm(meh.(svec));
    @time x = fsortperm(meh2.(svec));



    @time x = fsortperm6(svec);
    issorted(svec[x])

    fff(svec) = sort(svec, by = hash, alg=RadixSort)
    fff1(svec) = sort!(hash.(svec), alg=RadixSort)
    @time fff1(svec);
    @time fff(svec);

    # @time x = fsortperm4(svec);
    # issorted(svec[x])

    # using RCall
    # @rput svec
    # R"""
    # memory.limit(2^31-1)
    # system.time(sort(svec, method="radix"))
    # """
end
