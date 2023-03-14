import Base.Sort: uint_map
export uint_map

uint_map(x) = uint_map(x, Base.Forward)

uint_map(x::Float16, ::Base.ReverseOrdering) = ~reinterpret(Int16, x)
uint_map(x::Float16, ::Base.ForwardOrdering) = reinterpret(Int16, x)
uint_map(x::Float32, ::Base.ReverseOrdering) = ~reinterpret(Int32, x)
uint_map(x::Float32, ::Base.ForwardOrdering) = reinterpret(Int32, x)
uint_map(x::Float64, ::Base.ReverseOrdering) = ~reinterpret(Int64, x)
uint_map(x::Float64, ::Base.ForwardOrdering) = reinterpret(Int64, x)

uint_map(::Missing) = UInt(2)^8sizeof(UInt) - 1

uint_map(::Missing, _) = UInt(2)^8sizeof(UInt) - 1
