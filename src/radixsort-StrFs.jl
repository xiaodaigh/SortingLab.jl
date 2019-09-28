import SortingAlgorithms:uint_mapping
using SortingAlgorithms, StrFs

#export uint_mapping, radixsort

SortingAlgorithms.uint_mapping(::Base.Order.ReverseOrdering, s::StrF{S}) where S = begin
    res = s |> Ref |> pointer_from_objref |> Ptr{UInt128} |> unsafe_load

    # this might contain rubbish so need to clear them out
    ~(((res << (8*(16-sizeof(s)))) >> (8*(16-sizeof(s)))) |> ntoh)
end

SortingAlgorithms.uint_mapping(::Base.Order.ForwardOrdering, s::StrF{S}) where S  = begin
    res = s |> Ref |> pointer_from_objref |> Ptr{UInt128} |> unsafe_load
    ((res << (8*(16-sizeof(s)))) >> (8*(16-sizeof(s)))) |> ntoh
end

radixsort(v::Vector{StrF{S}}; rev = false) where S = begin
    if S <=16
        return sort(v, alg = RadixSort, rev = rev)
    else
        throw(ErrorException("radix sort of Vector{StrF(S)} is only possible for S <= 16 for now"))
    end
end
