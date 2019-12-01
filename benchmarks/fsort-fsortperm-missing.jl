x = rand(1:1_000_000, 100_000_000)

using SortingLab

using BenchmarkTools, SortingAlgorithms

base_sort = @belapsed sort(x)
sortingalg_sort = @belapsed sort(x, alg=RadixSort)
sortinglab_fsort = @belapsed fsort(x)

using Missings: allowmissing
x_w_missing = allowmissing(x)
x_w_missing[rand(1:length(x), 10_000_000)] .= missing

base_sort_wm = @belapsed sort(x_w_missing)
sortingalg_sort_wm = 0
sortingalg_sort_wm = @belapsed sort(x_w_missing, alg=RadixSort) # fails
sortinglab_fsort_wm = @belapsed fsort(x_w_missing)

using StatsPlots

g = groupedbar(
    repeat([" Base\n sort(x)", "SortingAlgorithms.jl\n sort(x, alg=RadixSort)", "  SortingLab.jl\n fsort(x)"], outer=2),
    [base_sort, sortingalg_sort, sortinglab_fsort,
    base_sort_wm, sortingalg_sort_wm, sortinglab_fsort_wm];
    group = repeat(["w/o missing", "with missing"], inner=3),
    ylab = "Seconds"
)

title!(g, "Sort 100m integer")

savefig(g, "benchmarks/fsort_missing_100m_int.png")

#######################
# sortperm
#######################

base_sortperm = @belapsed sortperm(x)
sortingalg_sortperm = @belapsed sortperm(x, alg=RadixSort)
sortinglab_fsortperm = @belapsed fsortperm(x)

base_sortperm_wm = @belapsed sortperm(x_w_missing)
sortingalg_sortperm_wm = 0
sortingalg_sortperm_wm = @belapsed sortperm(x_w_missing, alg=RadixSort) # fails
sortinglab_fsortperm_wm = @belapsed fsortperm(x_w_missing)

using StatsPlots

g2 = groupedbar(
    repeat([" Base\n sortperm(x)", "SortingAlgorithms.jl\n sortperm(x, alg=RadixSort)", "  SortingLab.jl\n fsortperm(x)"], outer=2),
    [base_sortperm, sortingalg_sortperm, sortinglab_fsortperm,
    base_sortperm_wm, sortingalg_sortperm_wm, sortinglab_fsortperm_wm];
    group = repeat(["w/o missing", "with missing"], inner=3),
    ylab = "Seconds"
)

title!(g2, "SortPerm 100m integer")

savefig(g2, "benchmarks/fsortperm_missing_100m_int.png")
