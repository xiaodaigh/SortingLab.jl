#using Base.Threads
import StatsBase: BaseRadixSortSafeTypes
import Base: Forward, ForwardOrdering, Reverse, ReverseOrdering, sortperm, Ordering,
            setindex!, getindex, similar, sort!, Reverse

import Base.Threads: nthreads, threadid

# create bits types for easy loading of bytes of lengths up to 15
primitive type Bits24 24 end
primitive type Bits40 40 end
primitive type Bits48 48 end
primitive type Bits56 56 end
primitive type Bits72 72 end
primitive type Bits80 80 end
primitive type Bits88 88 end
primitive type Bits96 96 end
primitive type Bits104 104 end
primitive type Bits112 112 end
primitive type Bits120 120 end

# winner from benchmarks/which_is_the_fastest_UInt_histogram.jl
"""
    uint_hist(bits, [RADIX_SIZE = 16, RADIX_MASK = 0xffff])
Computes a histogram (counts) for the vector RADIX_SIZE bits at a time. E.g. if eltype(bits) is UInt64 and RADIX_SIZE is 16
then 4 histograms are created for each of the 16 bit chunks.
"""
function uint_hist(bits::Vector{T}, RADIX_SIZE = 16, RADIX_MASK = 0xffff) where T
    #println("hello")
    iter = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    #hist = zeros(UInt32, 2^RADIX_SIZE, iter, nthreads())
    hist = zeros(UInt32, 2^RADIX_SIZE, iter)
    #@threads for j = 1:length(bits)
    for j = 1:length(bits)
        for i = 0:iter-1
            @inbounds hist[1+Int((bits[j] >> (i * RADIX_SIZE)) & RADIX_MASK), i+1] += 1
        end
    end
    #@threads for j in 1:iter
    # for j in 1:iter
    #     for i = 2:nthreads()
    #         @inbounds hist[:, j, 1] .+= hist[:, j, i]
    #     end
    # end
    hist
end

# sort it by using sorttwo! on the pointer
function sort_spointer!(svec::Vector{String}, lo::Int, hi::Int, o::O) where O <: Union{ForwardOrdering, ReverseOrdering}
    if lo >= hi;  return svec;  end
    # the length subarray to sort
    l = hi - lo + 1

    # find the maximum string length
    lens = maximum(sizeof, svec)
    skipbytes = lens

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
function sorttwo!(vs::Vector{T}, index, lo::Int = 1, hi::Int=length(vs), RADIX_SIZE = 16, RADIX_MASK = 0xffff) where T <:Union{BaseRadixSortSafeTypes}
    # Input checking
    if lo >= hi;  return (vs, index);  end
    #println(vs)
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
        for i in 2:nbuckets
            cbin[i] = cbin[i-1] + bin[i,j]
        end

        ci = cbin[idx]
        #println((ci, hi))
        ts[ci] = vs[hi]
        index1[ci] = index[hi]
        # println(cbin[idx])
        cbin[idx] -= 1

        # Finish the loop...
        #@inbounds
        for i in hi-1:-1:lo
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

# loads `remaining_bytes_to_load` bytes from `ptrs` which is a C-style pointer to a string
# these functions assumes that remaining_bytes_to_load > 0
function load_bits_with_padding(::Type{UInt128}, ptrs::Ptr{UInt8}, remaining_bytes_to_load)::UInt128
    nbits_to_shift_away = 8(sizeof(UInt128) - remaining_bytes_to_load)

    # the below checks if the string is less than 16 bytes away from the page
    # boundary assuming the page size is 4kb
    # see https://discourse.julialang.org/t/is-there-a-way-to-check-how-far-away-a-pointer-is-from-a-page-boundary/8147/11?u=xiaodai
    if (UInt(ptrs) & 0xfff) > 0xff0
        if  remaining_bytes_to_load == 15
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits120}(ptrs))))
        elseif  remaining_bytes_to_load == 14
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits112}(ptrs))))
        elseif  remaining_bytes_to_load == 13
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits104}(ptrs))))
        elseif  remaining_bytes_to_load == 12
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits96}(ptrs))))
        elseif  remaining_bytes_to_load == 11
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits88}(ptrs))))
        elseif  remaining_bytes_to_load == 10
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits80}(ptrs))))
        elseif  remaining_bytes_to_load == 9
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits72}(ptrs))))
        elseif  remaining_bytes_to_load == 8
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{UInt64}(ptrs))))
        elseif  remaining_bytes_to_load == 7
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits56}(ptrs))))
        elseif  remaining_bytes_to_load == 6
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits48}(ptrs))))
        elseif  remaining_bytes_to_load == 5
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits40}(ptrs))))
        elseif  remaining_bytes_to_load == 4
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{UInt32}(ptrs))))
        elseif  remaining_bytes_to_load == 3
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{Bits24}(ptrs))))
        elseif  remaining_bytes_to_load == 2
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{UInt16}(ptrs))))
        else
            return ntoh(Base.zext_int(UInt128, unsafe_load(Ptr{UInt8}(ptrs))))
        end
    else
        return ntoh(unsafe_load(Ptr{UInt128}(ptrs))) >> nbits_to_shift_away << nbits_to_shift_away
    end
end

function load_bits_with_padding(::Type{UInt64}, ptrs::Ptr{UInt8}, remaining_bytes_to_load)::UInt64
    nbits_to_shift_away = 8(sizeof(UInt64) - remaining_bytes_to_load)

    # the below checks if the string is less than 8 bytes away from the page
    # boundary assuming the page size is 4kb
    # see https://discourse.julialang.org/t/is-there-a-way-to-check-how-far-away-a-pointer-is-from-a-page-boundary/8147/11?u=xiaodai
    if (UInt(ptrs) & 0xfff) > 0xff8
        if  remaining_bytes_to_load == 7
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{Bits56}(ptrs))))
        elseif  remaining_bytes_to_load == 6
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{Bits48}(ptrs))))
        elseif  remaining_bytes_to_load == 5
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{Bits40}(ptrs))))
        elseif  remaining_bytes_to_load == 4
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{UInt32}(ptrs))))
        elseif  remaining_bytes_to_load == 3
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{Bits24}(ptrs))))
        elseif  remaining_bytes_to_load == 2
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{UInt16}(ptrs))))
        else
            return ntoh(Base.zext_int(UInt64, unsafe_load(Ptr{UInt8}(ptrs))))
        end
    else
        return ntoh(unsafe_load(Ptr{UInt64}(ptrs))) >> nbits_to_shift_away << nbits_to_shift_away
    end
end

function load_bits_with_padding(::Type{UInt32}, ptrs::Ptr{UInt8}, remaining_bytes_to_load)::UInt32
    nbits_to_shift_away = 8(sizeof(UInt32) - remaining_bytes_to_load)

    # the below checks if the string is less than 4 bytes away from the page
    # boundary assuming the page size is 4kb
    # see https://discourse.julialang.org/t/is-there-a-way-to-check-how-far-away-a-pointer-is-from-a-page-boundary/8147/11?u=xiaodai
    if (UInt(ptrs) & 0xfff) > 0xffc
        if  remaining_bytes_to_load == 3
            return ntoh(Base.zext_int(UInt32, unsafe_load(Ptr{Bits24}(ptrs))))
        elseif  remaining_bytes_to_load == 2
            return ntoh(Base.zext_int(UInt32, unsafe_load(Ptr{UInt16}(ptrs))))
        else
            return ntoh(Base.zext_int(UInt32, unsafe_load(Ptr{UInt8}(ptrs))))
        end
    else
        return ntoh(unsafe_load(Ptr{UInt32}(ptrs))) >> nbits_to_shift_away << nbits_to_shift_away
    end
end

"""
    load_bits([type,] s, skipbytes)

Load the underlying bits of a string `s` into a `type` of the user's choosing.
The default is `UInt`, so on a 64 bit machine it loads 64 bits (8 bytes) at a time.
If the `String` is shorter than 8 bytes then it's padded with 0.

- `type`:       any bits type that has `>>`, `<<`, and `&` operations defined
- `s`:          a `String`
- `skipbytes`:  how many bytes to skip e.g. load_bits("abc", 1) will load "bc" as bits
"""
# Some part of the return result should be padded with 0s.
# To prevent any possibility of segfault we load the bits using
# successively smaller types
# it is assumed that the type you are trying to load into needs padding
# i.e. `remaining_bytes_to_load > 0`
function load_bits(::Type{T}, s::String, skipbytes = 0)::T where T <: Unsigned
    n = sizeof(s)
    if n < skipbytes
        res = zero(T)
    elseif n - skipbytes >= sizeof(T)
        res = ntoh(unsafe_load(Ptr{T}(pointer(s, skipbytes+1))))
    else
        ptrs  = pointer(s) + skipbytes
        remaining_bytes_to_load = n - skipbytes
        res = load_bits_with_padding(T, ptrs, remaining_bytes_to_load)
    end
    return res
end

# Radix sort for strings
"""
    radixsort!(svec)

Applies radix sort to the string vector, svec, and sort it in place.
"""
function radixsort!(svec::AbstractVector{String}, lo::Int, hi::Int, o::O; RADIX_SIZE = 16, RADIX_MASK = 0xffff) where O <: Union{ForwardOrdering, ReverseOrdering}
    if lo >= hi;  return svec;  end
    # the length subarray to sort
    l = hi - lo + 1

    # find the maximum string length
    lens = maximum(sizeof, svec)
    skipbytes = lens
    if lens > 0
        # while lens > 8
        #     skipbytes = max(0, skipbytes - 16)
        #     bits128 = zeros(UInt128, l)
        #     if o == Reverse
        #         bits128[lo:hi] .= .~load_bits.(UInt128, @view(svec[lo:hi]), skipbytes)
        #         sorttwo!(bits128, svec, lo, hi)
        #     else
        #         bits128[lo:hi] .= load_bits.(UInt128, @view(svec[lo:hi]), skipbytes)
        #         sorttwo!(bits128, svec, lo, hi)
        #     end
        #     lens -= 16
        # end
        while lens > 4
            skipbytes = max(0, skipbytes - 8)
            bits64 = zeros(UInt64, l)
            if o == Reverse
                bits64[lo:hi] .= .~load_bits.(UInt64, @view(svec[lo:hi]), skipbytes)
                sorttwo!(bits64, svec, lo, hi, RADIX_SIZE, RADIX_MASK)
            else
                bits64[lo:hi] .= load_bits.(UInt64, @view(svec[lo:hi]), skipbytes)
                sorttwo!(bits64, svec, lo, hi, RADIX_SIZE, RADIX_MASK)
            end
            lens -= 8
        end
        if lens > 0
            skipbytes = max(0, skipbytes - 4)
            bits32 = zeros(UInt32, l)
            if o == Reverse
                bits32[lo:hi] .= .~load_bits.(UInt32, @view(svec[lo:hi]), skipbytes)
                sorttwo!(bits32, svec, lo, hi, RADIX_SIZE, RADIX_MASK)
            else
                bits32[lo:hi] .= load_bits.(UInt32, @view(svec[lo:hi]), skipbytes)
                sorttwo!(bits32, svec, lo, hi, RADIX_SIZE, RADIX_MASK)
            end
            lens -= 4
        end
    end
    svec
end

"""
    radixsort(svec, rev = false)

Applies radix sort to the string vector, svec, and sort it in place.
"""
fsort(svec::Vector{String}, rev = false, radix_opts = (16, 0xffff)) = radixsort(svec, rev , (16, 0xffff))
fsort!(svec::Vector{String}, rev = false, radix_opts = (16, 0xffff)) = radixsort!(svec, rev , (16, 0xffff))
radixsort(svec::Vector{String}, rev = false, radix_opts = (16, 0xffff)) = radixsort!(copy(svec), rev, radix_opts)
radixsort!(svec::Vector{String}, rev = false, radix_opts = (16, 0xffff)) =  radixsort!(svec, 1, length(svec), rev ? Base.Reverse : Base.Forward, RADIX_SIZE = radix_opts[1], RADIX_MASK = radix_opts[2])
