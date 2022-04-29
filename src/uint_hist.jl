# winner from benchmarks/which_is_the_fastest_UInt_histogram.jl
"""
    uint_hist(bits, [RADIX_SIZE = 16, RADIX_MASK = 0xffff])
    
Computes a histogram (counts) for the vector RADIX_SIZE bits at a time. E.g. if eltype(bits) is UInt64 and RADIX_SIZE is 16
then 4 histograms are created for each of the 16 bit chunks.
"""
function uint_hist(bits::AbstractVector{T}, RADIX_SIZE = 16, RADIX_MASK = 0xffff) where T
    iter = ceil(Integer, sizeof(T)*8/RADIX_SIZE)
    hist = zeros(UInt32, 2^RADIX_SIZE, iter)

    for j = 1:length(bits)
        for i = 0:iter-1
            @inbounds hist[1+Int((uint_mapping(bits[j]) >> (i * RADIX_SIZE)) & RADIX_MASK), i+1] += 1
        end
    end
    hist
end
