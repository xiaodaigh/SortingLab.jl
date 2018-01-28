# the purpose of this file is to find a winner for the fastest histogram
# It was found that (unsurprisingly) the multithreaded version is faster
# actually the story is a bit murky now and it's best to wait for v0.7.0
# I seem to find type instability issues with the threadedcount code
# but it disappeared in v0.7.0, so waiting might be a good strategy
tic()
using Base.Threads
using Plots
using BenchmarkTools, DataFrames
import SortingAlgorithms: uint_mapping, RADIX_MASK, RADIX_SIZE, load_bits

# multi-threaded histogram count
# there seems to be some instability
function threadedcount(bits::Vector{T}) where T <: Unsigned
    iter = sizeof(T)÷2::Int
    hist = zeros(UInt32, 65536, iter, nthreads())
    l = length(bits)::Int
    @threads for j = 1:l
        # for i = 0:iter-1
        #     # idx = (bits[j] >> (i << 4)) & T(0xffff)
        #     # idx = bits[j]
        #     # @inbounds hist[idx, i+1, threadid()] += 1
        # end
    end
    nt = Threads.nthreads()
    @threads for j in 1:iter
        for i = 2:nt
            # @inbounds hist[:, j, 1] .+= hist[:, j, i]
        end
    end
    hist[:,:,1]
end

@code_warntype threadedcount()

# single threaded histogram count from SortingAlgorithms.jl
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

function count64(bits::Vector{T}) where T<:Unsigned
    hist = zeros(UInt32, 1<<16, 4)
    for x1 in bits
        for i in 0:sizeof(T)÷2-1
            @inbounds hist[1+Int((x1 >> (i << 4)) & 0xffff), i+1] += 1
        end
    end
    hist
end

function count16(bits::Vector{T}) where T<:Unsigned
    hist = zeros(UInt32, 1<<16, 4)
    hist_hot = zeros(UInt16, 1<<16)
    @inbounds for i in 0:sizeof(T)÷2-1
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

function count8(bits::Vector{T}) where T<:Unsigned
    hist = zeros(UInt32, 1<<16, 4)
    hist_hot = zeros(UInt8, 1<<16)
    @inbounds for i in 0:sizeof(T)÷2-1
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

function count8t(bits::Vector{T}) where T<:Unsigned
    hist = zeros(UInt32, 1<<16, sizeof(T)÷2)
    hist_hot = zeros(UInt8, 1<<16, sizeof(T)÷2)
    @threads for i in 0:sizeof(T)÷2-1
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

function count8x(bits::Vector{T}) where T<:Unsigned
    hists = [zeros(UInt32, 1<<16) for i in 1:sizeof(T)÷2]
    hists_hot = [zeros(UInt8, 1<<16) for i in 1:sizeof(T)÷2]
    @threads for i in 0:sizeof(T)÷2-1
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

function test_histogram(N,K)
    @time samplespace = "id".*dec.(1:N÷K,10);
    @time svec = rand(load_bits.(UInt32, samplespace), N);

    naiveres = @belapsed threadedcount($svec)
    sortingalgorithms = @belapsed hist_sortingalgorithms($svec)
    count64res = @belapsed count64($svec)
    count16res = @belapsed count16($svec)
    count8res = @belapsed count8($svec)
    count8tres = @belapsed count8t($svec)
    count8xres = @belapsed count8x($svec)

    first4res = DataFrame(
        alg = ["orig",    "SortingAlgorithms.jl", "count64",  "count16",  "count8",   
            "count8t",  "count8x"],
        timing = [naiveres,  sortingalgorithms,      count64res, count16res, count8res, 
            count8tres,  count8xres])


    b1 = bar(first4res[:alg], first4res[:timing], 
        label="time (sec)", title = "sort first 4 bytes - $(N/1_000_000)m")

    @time svec = rand(load_bits.(UInt, samplespace, 4), N);
    gc()
    naiveres = @belapsed threadedcount($svec)
    sortingalgorithms = @belapsed hist_sortingalgorithms($svec)
    count64res = @belapsed count64($svec)
    count16res = @belapsed count16($svec)
    count8res = @belapsed count8($svec)
    count8tres = @belapsed count8t($svec)
    count8xres = @belapsed count8x($svec)

    last8res = DataFrame(
        alg = ["orig",    "SortingAlgorithms.jl", "count64",  "count16",  "count8",   
            "count8t",  "count8x"],
        timing = [naiveres,  sortingalgorithms,      count64res, count16res, count8res, 
            count8tres,  count8xres])

    b2 = bar(last8res[:alg], last8res[:timing], 
        label="time (sec)", title = "sort last 8 bytes - $(N/1_000_000)m")

    plot(b1,b2)
    savefig("compare_rbench_count_uint.png")

    first4res, last8res, b1, b2
end

test_histogram(1_000_000, 100)


res = test_histogram(100_000_000, 100)
toc()

N = 1000
K = 100
import SortingLab: load_bits
@time samplespace = "id".*dec.(1:N÷K,10);
@time svec = rand(load_bits.(UInt32, samplespace), N);
@code_warntype threadedcount(svec)

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

# function abc(bits::Vector{T}) where T <: Unsigned
#     iter = sizeof(T)÷2::Int
#     # hist = zeros(UInt32, 65536, iter, nthreads())
#     # l = length(bits)::Int
#     # @threads for j = 1:l
#     #     # for i = 0:iter-1
#     #     #     # idx = (bits[j] >> (i << 4)) & T(0xffff)
#     #     #     # idx = bits[j]
#     #     #     # @inbounds hist[idx, i+1, threadid()] += 1
#     #     # end
#     # end
#     nt = Threads.nthreads()
#     @threads for k in 1:iter
#         for i = 2:nt
#             # @inbounds hist[:, j, 1] .+= hist[:, j, i]
#         end
#     end
#     # hist[:,:,1]
#     1
# end

# @code_warntype abc(svec)

# function def()
#     @threads for j = 1:8
#     end

#     @threads for k = 1:8
#     end

#     nothing
# end

# @code_warntype def()