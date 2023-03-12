if false
    Threads.nthreads()
end

function blockranges(nblocks, total_len)
    rem = total_len % nblocks
    main_len = div(total_len, nblocks)

    starts=Int[1]
    ends=Int[]
    for ii in 1:nblocks
        len = main_len
        if rem>0
            len+=1
            rem-=1
        end
        push!(ends, starts[end]+len-1)
        push!(starts, ends[end] + 1)
    end
    @assert ends[end] == total_len
    starts[1:end-1], ends
end



# import Hwloc
# topology = Hwloc.topology_load()
# l1cache = first(filter(t->t.type_==:Cache && t.attr.depth==1, topology)).attr

# l1cache = filter(t->t.type_==:Cache && t.attr.depth==1, topology)
# println("L1 cache information: $l2cache")
using BenchmarkTools, FastGroupBy, Base.Threads
import FastGroupBy.load_bits
function paradissort2!(svec::Vector{String}, rev = false, counter_type::Type{CT} = UInt) where CT <: Unsigned
    bits = load_bits.(UInt, svec)
    hist = zeros(CT, 1 << 16, 4, nthreads())
    @threads for j = 1:length(bits)
        for i = 0:3
            @inbounds hist[1+Int((bits[j] >> (i << 4)) & 0xffff), i+1, threadid()] += 1
        end
    end
    @threads for j in 1:4
        for i = 2:nthreads()
           @inbounds hist[:, j, 1] .+= hist[:, j, i]
        end
    end
    hist[:,:,1]
end

# this is provided for timing control
# DO NOT DELETE
function paradissort2a!(svec::Vector{String}, rev = false)
    bits = load_bits.(UInt, svec)
    hist = zeros(UInt, 65536, 4)
    for x1 in bits
        for i in 0:3
            @inbounds hist[1+Int((x1 >> (i << 4)) & 0xffff), i+1] += 1
        end
    end
    hist
end

function paradissort2a8!(svec::Vector{String}, rev = false)
    bits = load_bits.(UInt, svec)
    hist = zeros(UInt, 1<<16, 4)
    hist_hot = zeros(UInt8, 1<<16)
    @inbounds for i in 0:3
        for x1 in bits
            idx = 1+ Int((x1 >> (i << 4)) & 0xffff)
            hist_hot[idx] += UInt8(1)
            if hist_hot[idx] == 0
                hist[idx, i+1] += (1<<8)
            end            
        end
        for idx in 1:(1<<16)
            hist[idx,i+1] += hist_hot[idx]
        end
        fill!(hist_hot, zero(UInt8))
    end
    hist
end

function paradissort2a8t!(svec::Vector{String}, rev = false)
    bits = load_bits.(UInt, svec)
    hist = zeros(UInt64, 1<<16, 4)
    hist_hot = zeros(UInt8, 1<<16, 4)
    @threads for i in 0:3 
        @inbounds for x1 in bits
            idx = 1+ Int((x1 >> (i << 4)) & 0xffff)
            hist_hot[idx,i+1] += UInt8(1)
            if hist_hot[idx,i+1] == 0
                hist[idx, i+1] += (1<<8)
            end            
        end
        @inbounds for idx in 1:(1<<16)
            hist[idx,i+1] += hist_hot[idx, i+1]            
        end
    end
    hist
end

# svec = rand("id".*dec.(1:1_000_000,10), 100_000_000);
svec = rand([randstring(8) for i =1:1_000_000], 100_000_000);
using BenchmarkTools
t1 = @belapsed a = paradissort2!($svec, false, UInt16);
t2 = @belapsed b = paradissort2a!($svec);
t3 = @belapsed c = paradissort2a8!($svec);
t4 = @belapsed d = paradissort2a8t!($svec);
(a .== b) |> all
(a .== c) |> all
(a .== d) |> all
using Plots
bar(["naive threaded", "naive", "count8", "count8t"], [t1,t2,t3, t4])


@time radixsort!(svec)

ss = 1
ee = 25_000_000
x = svec[ss:ee];
function abc(x)
    @time FastGroupBy.radixsort!(x)
end
@time abc(x);

function def(x)
    @time FastGroupBy.radixsort!(@view(svec[ss:ee]))
end
@time def(x);


@time xx = paradissort2!(svec);
