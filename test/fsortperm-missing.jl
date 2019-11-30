using Test
using SortingLab

x = [1,2,missing, 3]

@test isequal(fsortperm(x), sortperm(x))
