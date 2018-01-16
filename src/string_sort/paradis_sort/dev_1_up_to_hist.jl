using BenchmarkTools, FastGroupBy, Base.Threads
import FastGroupBy.load_bits

# This seems to be the fastest counter; see benchmark src/which_is_the_fastest_UInt_histogram.jl
# creates a histogram of each of 16bits that make up the 64bit arrays
function hist_uint(bits, htype::Type{T} = UInt) where T <: Unsigned
    hist = zeros(T, 1<<16, 4, nthreads())
    @threads for j = 1:length(bits)
        for i = 0:3
            @inbounds hist[1 + Int((bits[j] >> (i << 4)) & 0xffff), i+1, threadid()] += 1
        end
    end
    @threads for j in 1:4
        for i = 2:nthreads()
           @inbounds hist[:, j, 1] .+= hist[:, j, i]
        end
    end
    hist[:,:,1]
end

function paradissort2!(svec::Vector{String}, rev = false, counter_type::Type{CT} = UInt) where CT <: Unsigned
    len = maximum(sizeof,sizeof(svec))
    skipbytes = 0 

    bits = load_bits.(UInt, svec, skipbytes)
    hist = hist_uint(bits, counter_type)
    skipbytes += 8
    len -= 8

    while len > 0
        bits = load_bits.(UInt, svec, skipbytes)
        hist = hist_uint(bits, counter_type)
        skipbytes += 8
        len -= 8
    end
    hist
end

# this is provided for timing control
# DO NOT DELETE
function paradissort2_single!(svec::Vector{String}, rev = false)
    len = maximum(sizeof,sizeof(svec))
    skipbytes = 0

    bits = load_bits.(UInt, svec)

    # build a histogram of the first 8 bytes
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
    skipbytes += 8
    len -= 8

    while len > 0
        bits = load_bits.(UInt, svec)
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
        skipbytes += 8
        len -= 8
    end
    
    # the gap at this point is 1.75 seconds

    # use the histogram

    hist
end

N = 100_000_000
K = 100
svec = rand(["id".*dec.(i,10) for i = 1:N÷K], N);

using BenchmarkTools
gc()
@btime paradissort2!($svec);
gc()
@btime paradissort2_single!($svec);
# the gap is 1.7 seconds at this point