export uint_mapping

import SortingAlgorithms: uint_mapping

uint_mapping(x) = uint_mapping(Base.Forward, x)

uint_mapping(::Missing) = UInt(2)^8sizeof(UInt)-1

uint_mapping(_, ::Missing) = UInt(2)^8sizeof(UInt)-1
