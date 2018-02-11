function g2(byvec, valvec)
    cv = copy(valvec)
    cb = copy(byvec)
    FastGroupBy.grouptwo!(cb, cv)
    cv, cb
end

a = rand([randstring(8) for i=1:100_000], 10_000_000)
x = rand(10_000_000)

gc_enable(false)
@time g2(a,x);
gc_enable(true)

function g3(byvec, valvec)
    bv = collect(zip(Ptr{UInt}.(pointer.(byvec)), valvec))
    sort!(bv, by=x->unsafe_load(x[1]), alg = RadixSort)
end

gc_enable(false)
@time g3(a,x);
gc_enable(true)

import SortLab.load_bits

function ptrload(ptrs, skipbytes = 0)::T where T <: Unsigned
    n = sizeof(s)
    if n < skipbytes
        res = zero(T)
    elseif n - skipbytes >= sizeof(T)
        res = ntoh(unsafe_load(ptrs + skipbytes))
    else
        ptrs  = pointer(s) + skipbytes
        remaining_bytes_to_load = n - skipbytes
        res = load_bits_with_padding(T, ptrs, remaining_bytes_to_load)
    end
    return res
end

# SortingLab.load_bits(UInt, a[1], 2)
function strsort3!(svec)
    ms = maximum(sizeof, svec)
    ms = max(0, ms - sizeof(UInt))

    vs = Ptr{UInt}.(pointer.(svec))
    sort!(vs,by= x->x[1], alg=RadixSort)

    # @time  while ms > 0
    #     sort!(svec, by=x->SortingLab.load_bits(UInt, x, ms) , alg = RadixSort)
    #     ms -= max(0, sizeof(UInt))
    # end
    [vs1[2] for vs1 in vs]
end

strsort3(svec) = strsort3!(copy(svec))

gc_enable(false)
@time bb = strsort3(a)
issorted(bb)
gc_enable(true)

using SortingLab, SortingAlgorithms

srand(1);
svec = rand([randstring(8) for i=1:1_000_000], 100_000_000)
function pointersort(svec)
    # sp = 
    @inbounds sv = collect(zip(1:length(svec), unsafe_load.(Ptr{UInt}.(pointer.(svec)))))
    # sv = Vector{Tuple{Ptr{UInt8}, UInt}}(length(svec))
    # for (i,s) in enumerate(svec)
    #     sp = pointer(s)
    #     sv[i] = tuple(sp, ntoh(unsafe_load(Ptr{UInt}(sp))))
    # end
    @inbounds sort!(sv, by=x->x[2], alg=RadixSort)
    @inbounds pos = [sv1[1] for sv1 in sv]
    @inbounds svec[pos]
end

gc_enable(false)
@time pointersort(svec);
@code_warntype pointersort(svec)
gc_enable(true)

gc_enable(false)
@time fsort(svec);
gc_enable(true)

function strsort5(svec)
    ps = Ptr{UInt}.(pointer.(svec))
    vs = collect(zip(ps, ntoh.(unsafe_load.(ps))))
    sort!(vs, by=x->x[2], alg=RadixSort)
    unsafe_string.(Ptr{UInt8}.(getindex.(vs,1)))
end


@time sort(svec)
using BenchmarkTools
@benchmark pointersort($svec) samples=5 seconds=120




gc_enable(false)
gc_enable(true)

gc_enable(false)
@time fsort(svec);
gc_enable(true)

@time fsortperm(svec)

using RCall
R"""
memory.limit(2^31-1)
"""
@rput svec;
rres = R"""
replicate(5, system.time(sort(svec, method="radix"))[3])
"""
mean(rres)


@time a = strsort5(svec);

@code_warntype strsort5(svec);
fsort(svec[1:1])
@time aa = fsort(svec);
all(a == aa)


x = "abc"
pointer(x)
pointer(x) - 8
pointer_from_objref(x) |> unsafe_pointer_to_objref


pointer_from_objref(svec[1]) |> unsafe_pointer_to_objref
pointer(svec)

# SortingLab.load_bits(UInt, a[1], 2)
function strsort!(svec)
    ms = maximum(sizeof, svec)
    ms = max(0, ms - sizeof(UInt))

    @time sort!(svec, by=x->SortingLab.load_bits(UInt, x, ms) , alg = RadixSort)

    @time  while ms > 0
        sort!(svec, by=x->SortingLab.load_bits(UInt, x, ms) , alg = RadixSort)
        ms -= max(0, sizeof(UInt))
    end
    svec
end

strsort(svec) = strsort!(copy(svec))

@time bb = strsort(a)
@code_warntype strsort(a)
issorted(bb)

using SortingLab
@time bb = fsort(a)
issorted(bb)


# SortingLab.load_bits(UInt, a[1], 2)
function strsort2!(svec)
    ms = maximum(sizeof, svec)
    ms = max(0, ms - sizeof(UInt))

    vs = collect(zip(SortingLab.load_bits.(UInt, svec, ms), svec))
    sort!(vs,by= x->x[1], alg=RadixSort)

    # @time  while ms > 0
    #     sort!(svec, by=x->SortingLab.load_bits(UInt, x, ms) , alg = RadixSort)
    #     ms -= max(0, sizeof(UInt))
    # end
    [vs1[2] for vs1 in vs]
end

strsort2(svec) = strsort2!(copy(svec))

gc_enable(false)
@time bb = strsort2(a)
issorted(bb)
gc_enable(true)
