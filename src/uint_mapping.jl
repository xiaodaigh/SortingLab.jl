export uint_mapping

# import SortingAlgorithms: uint_mapping

uint_mapping(x) = uint_mapping(Base.Forward, x)

uint_mapping(::Missing) = UInt(2)^8sizeof(UInt)-1

uint_mapping(_, ::Missing) = UInt(2)^8sizeof(UInt)-1

# the below comes from SortingAlgorithms.jl
# Map a bits-type to an unsigned int, maintaining sort order
uint_mapping(::ForwardOrdering, x::Unsigned) = x
for (signedty, unsignedty) in ((Int8, UInt8), (Int16, UInt16), (Int32, UInt32), (Int64, UInt64), (Int128, UInt128))
    # In Julia 0.4 we can just use unsigned() here
    @eval uint_mapping(::ForwardOrdering, x::$signedty) = reinterpret($unsignedty, xor(x, typemin(typeof(x))))
end
uint_mapping(::ForwardOrdering, x::Float32)  = (y = reinterpret(Int32, x); reinterpret(UInt32, ifelse(y < 0, ~y, xor(y, typemin(Int32)))))
uint_mapping(::ForwardOrdering, x::Float64)  = (y = reinterpret(Int64, x); reinterpret(UInt64, ifelse(y < 0, ~y, xor(y, typemin(Int64)))))

uint_mapping(::Sort.Float.Left, x::Float16)  = ~reinterpret(Int16, x)
uint_mapping(::Sort.Float.Right, x::Float16)  = reinterpret(Int16, x)
uint_mapping(::Sort.Float.Left, x::Float32)  = ~reinterpret(Int32, x)
uint_mapping(::Sort.Float.Right, x::Float32)  = reinterpret(Int32, x)
uint_mapping(::Sort.Float.Left, x::Float64)  = ~reinterpret(Int64, x)
uint_mapping(::Sort.Float.Right, x::Float64)  = reinterpret(Int64, x)

uint_mapping(rev::ReverseOrdering, x) = ~uint_mapping(rev.fwd, x)
uint_mapping(::ReverseOrdering{ForwardOrdering}, x::Real) = ~uint_mapping(Forward, x) # maybe unnecessary; needs benchmark

uint_mapping(o::By,   x     ) = uint_mapping(Forward, o.by(x))
uint_mapping(o::Perm, i::Int) = uint_mapping(o.order, o.data[i])
uint_mapping(o::Lt,   x     ) = error("uint_mapping does not work with general Lt Orderings")

const RADIX_SIZE = 11
const RADIX_MASK = 0x7FF