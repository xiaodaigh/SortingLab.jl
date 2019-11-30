using Test
using SortingLab

x = [1,2,missing, 3]

SortingLab.sorttwo!(x, collect(1:4))
fsortperm(x)

@test isequal(sort(x), fsort(x))
