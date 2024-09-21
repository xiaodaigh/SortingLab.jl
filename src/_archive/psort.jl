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

function _threadedsort(data::Vector)
    starts, ends = blockranges(nthreads(), length(data))

    # Sort each block
    @threads for (ss, ee) in collect(zip(starts, ends))
        @inbounds sort!(@view(data[ss:ee]))
    end


    # Go through each sorted block taking out the smallest item and putting it in the new array
    # This code could maybe be optimised. see https://stackoverflow.com/a/22057372/179081
    # ret = similar(data) # main bit of allocation right here. avoiding it seems expensive.
    # # Need to not overwrite data we haven't read yet
    # @inbounds for ii in eachindex(ret)
    #     minblock_id = 1
    #     ret[ii]=data[starts[1]]
    #     @inbounds for blockid in 2:endof(starts) # findmin allocates a lot for some reason, so do the find by hand. (maybe use findmin! ?)
    #         ele = data[starts[blockid]]
    #         if ret[ii] > ele
    #             ret[ii] = ele
    #             minblock_id = blockid
    #         end
    #     end
    #     starts[minblock_id]+=1 # move the start point forward
    #     if starts[minblock_id] > ends[minblock_id]
    #         deleteat!(starts, minblock_id)
    #         deleteat!(ends, minblock_id)
    #     end
    # end
    # return ret
    # data.=ret  # copy back into orignal as we said we would do it inplace
    # return data
end

# parallel sorting algorithms based on https://stackoverflow.com/questions/47235390/how-can-i-parallelize-sorting/47235391#47235391
# the problem with this sort is that it only performs better if the number of unique elements is large
# see below for benchmarking code
threadedsort(a) = _threadedsort(copy(a))

if false
# a = rand(Int, 100_000_000);
# tic()
# @time threadedsort(a);
# toc()


# @time sort(a, alg=RadixSort);

    a = rand(1:40_000_000, 100_000_000);
    @time threadedsort(a);
    @time sort(a, alg=RadixSort);
    @time sort(a);
end
