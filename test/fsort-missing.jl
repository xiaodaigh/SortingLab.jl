using Test
using SortingLab

x = [1,2,missing, 3]

@test isequal(sort(x), fsort(x))
