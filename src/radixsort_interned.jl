ptrs(s::InternedString) = pointer(s.value)

# the fast radixsort for internedstrings
function radixsort(svec::AbstractVector{InternedString})
    p = InternedStrings.pool
    l = length(p)

    pointer_pstr = UInt.(pointer.(collect(keys(p))))
    # sorting the pointers will make it easy to look up
    sort!(pointer_pstr)

    pointer_svec = UInt.(ptrs.(svec))
    sort!(pointer_svec)
    
    cnts = zeros(UInt32, l)
    last_ps = pointer_svec[1]
    lo = 1
    @inbounds for i = 2:length(pointer_svec)
        next_ps = pointer_svec[i]
        if  next_ps != last_ps
            idx = searchsortedfirst(pointer_pstr, last_ps)
            cnts[idx] += i - lo
            last_ps = next_ps
            lo = i
        end
    end

    idx = searchsortedfirst(pointer_pstr, pointer_svec[end])
    cnts[idx] = length(pointer_svec) - lo + 1

    # pointer_pstr, cnts

    # # # load the strings based on pointers
    pstr = Base.unsafe_pointer_to_objref.(Ptr{UInt8}.(pointer_pstr) .- 8)
    # pstr, cnts

    # this index here will tell you how to sort
    # sort the strings and return the order
    # once you look up the position of pointer then can use this to look up
    # the right index
    indexes = fsortperm(pstr)
    pstr .= Base.unsafe_pointer_to_objref.(Ptr{UInt8}.(pointer_pstr[indexes]) .- 8)
    pstr, cnts[indexes]
    StatsBase.inverse_rle(pstr, cnts[indexes])

    # cnts .= cnts[indexes]

    # pstr .= pstr[indexes]
    # pstr, cnts
     
    # bad combination
    # res = StatsBase.inverse_rle(@view(pointer_pstr[indexes]), @view(cnts[indexes]))
    # Base.unsafe_pointer_to_objref.(Ptr{UInt8}.(res) .- 8)
end



# this is slow due to string searchedsortedfirst not being very fast for strings
# but would be good at some point in the future to test again once it is faster
function radixsort1(svec::AbstractVector{InternedString})
    p = InternedStrings.pool

    pstr = collect(keys(p))
    sort!(pstr)

    cnts = zeros(UInt32, length(p))

    @inbounds for ss in svec
        idx = searchsortedfirst(pstr, ss.value)
        cnts[idx] += 1
    end
    cnts
end
