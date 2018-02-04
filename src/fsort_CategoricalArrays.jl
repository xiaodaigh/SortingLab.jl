function fsort!(vec::CategoricalArray)
    cnts = zeros(UInt, length(vec.pool))

    @inbounds for r in vec.refs
        cnts[r] += 1
    end

    # vec.refs .= StatsBase.inverse_rle(1:length(vec.pool), cnts) # the below is 5x faster
    j = 0
    @inbounds for ref in 1:length(vec.pool)
        for k = 1:cnts[ref]
            j += 1
            vec.refs[j] = ref
        end
    end

    vec
end

fsort(vec::CategoricalArray) = fsort!(copy(vec))


function fsort2!(vec::CategoricalArray)
    Base.Sort.sort_int_range!(vec.refs, length(vec.pool), 0)
    vec
end

fsort2(vec::CategoricalArray) = fsort2!(copy(vec))