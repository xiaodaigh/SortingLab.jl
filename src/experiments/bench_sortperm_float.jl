using SortingLab, SortingAlgorithms

a = rand(Float32, 1_000_000)

sortperm_sorttwo(x) = begin
	i = collect(1:length(x))
	SortingLab.sorttwo!(copy(x), i)
	i
end

@time fsortperm(a)
@time sortperm(a)
@time sortperm(a, alg=RadixSort)
@time ass = sortperm_sorttwo(a)

using BenchmarkTools
@benchmark fsortperm(a)
@benchmark sortperm(a)
@benchmark sortperm(a, alg=RadixSort)
@benchmark ass = sortperm_sorttwo(a)

# sortperm_sorttwo seems to win out!
# which is implemented in fsortperm()
