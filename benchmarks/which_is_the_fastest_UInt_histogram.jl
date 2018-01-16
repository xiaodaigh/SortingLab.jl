
using Base.Threads
using Plots
using BenchmarkTools, DataFrames
import SortingAlgorithms: uint_mapping, RADIX_MASK, RADIX_SIZE, load_bits

using Base.Threads

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

function hist_sortingalgorithms(bits::Vector{T}) where T<:Unsigned
    iters = sizeof(T)÷2
    bin = zeros(UInt32, 65536, iters)

    # Histogram for each element, radix
    for v = bits
        for j = 1:iters
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            @inbounds bin[idx,j] += 1
        end
    end
end


function count64(bits)
    hist = zeros(UInt, 1<<16, 4)
    for x1 in bits
        for i in 0:3
            @inbounds hist[1+Int((x1 >> (i << 4)) & 0xffff), i+1] += 1
        end
    end
    hist
end

function count16(bits)
    hist = zeros(UInt64, 1<<16, 4)
    hist_hot = zeros(UInt16, 1<<16)
    @inbounds for i in 0:3
        for x1 in bits
            idx = 1+ Int((x1 >> (i << 4)) & 0xffff)
            hist_hot[idx] += UInt16(1)
            if hist_hot[idx] == 0
                hist[idx, i+1] += (1<<16)
            end            
        end
        for idx in 1:(1<<16)
            hist[idx,i+1] += hist_hot[idx]
        end
        fill!(hist_hot, zero(UInt16))
    end
    hist
end

function count8(bits)
    hist = zeros(UInt64, 1<<16, 4)
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

function count8t(bits)
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

function count8x(bits)
    hists = [zeros(UInt64, 1<<16) for i in 1:4]
    hists_hot = [zeros(UInt8, 1<<16) for i in 1:4]
    @threads for i in 0:3
        hist = hists[i+1]
        hist_hot = hists_hot[i+1]
        i4 = UInt8(i<<4)
        @inbounds for x1 in bits
            idx = 1+ Int((x1 >> i4) & 0xffff)
            hist_hot[idx] += UInt8(1)
            if hist_hot[idx] == 0
                hist[idx] += (1<<8)
            end
        end
        @inbounds for idx in 1:(1<<16)
            hist[idx] += hist_hot[idx]
        end
    end
    hcat(hists...)
end

using BenchmarkTools
N = 100_000_000
K = 100
@time samplespace = "id".*dec.(1:N÷K,10);
@time svec = rand(samplespace, N)
bits = load_bits.(UInt32, svec, 0)
@time uint_hist(bits);
@time hist_sortingalgorithms(bits);




@time svec = rand(load_bits.(UInt, samplespace), N);
gc()



naiveres = @belapsed threadedcount($svec)
count64res = @belapsed count64($svec)
count16res = @belapsed count16($svec)
count8res = @belapsed count8($svec)
count8tres = @belapsed count8t($svec)
count8xres = @belapsed count8x($svec)

b1 = bar(["orig","count64","count16","count8", "count8t","count8x"], [naiveres, count64res, count16res, count8res, count8tres, count8xres], label="time (sec)", title = "sort first 8 bytes")
#savefig("Single vs Multithreaded count.png")

@time svec = rand(load_bits.(UInt, samplespace, 8), N);
gc()
naiveres = @belapsed threadedcount($svec)
count64res = @belapsed count64($svec)
count16res = @belapsed count16($svec)
count8res = @belapsed count8($svec)
count8tres = @belapsed count8t($svec)
count8xres = @belapsed count8x($svec)

b2 = bar(["orig","count64","count16","count8", "count8t","count8x"], [naiveres, count64res, count16res, count8res, count8tres, count8xres], label="time (sec)", title = "sort next 6 bytes")

plot(b1,b2)
savefig("compare_rbench_count_uint.png")


# @btime threadedcount($svec);
# @btime threadedcount($svec, UInt32); # a bit slower but uses only half the memory



# svec = rand(rand(UInt, 10_000_000), 1_000_000_000);
# d = @elapsed threadedcount(svec)
# a = @elapsed count64(svec)
# b = @elapsed count16(svec)
# c1 = @elapsed count8(svec)
# c = @elapsed count8t(svec)
# f = @elapsed count8x(svec)


# savefig("Single vs Multithreaded countall.png")

# using Plots
# using BenchmarkTools
# svec = rand(rand(UInt(1):UInt(10_000_000), 10_000_000), 1_000_000_000);
# d = @elapsed threadedcount(svec)
# a = @elapsed count64(svec)
# b = @elapsed count16(svec)
# c1 = @elapsed count8(svec)
# c = @elapsed count8t(svec)
# f = @elapsed count8x(svec)

# bar(["orig","count64", "count16","count8", "count8t", "count8x"], [d, a, b,c1, c, f], label="time (sec)")
# savefig("Single vs Multithreaded count.png")

# bar(["orig","count16","count8", "count8t", "count8x"], [d, b,c1, c, f], label="time (sec)")
# savefig("Single vs Multithreaded count.png")