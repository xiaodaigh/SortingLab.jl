import Base.Sort:  uint_map
export uint_map

uint_map(x) = uint_map(x, Base.Forward)

uint_map(::Missing) = UInt(2)^8sizeof(UInt)-1

uint_map(::Missing, _) = UInt(2)^8sizeof(UInt)-1
