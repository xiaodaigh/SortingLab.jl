# sort integer with missing
x = allowmissing(rand(1:10_000, 1_000_000))
x[rand(1:length(x), 100_000)] .= missing
@test isequal(fsort(x), sort(x))

int_missing_fsort_timing = @belapsed fsort(x);
int_missing_sort_timing = @belapsed sort(x);

# sort integer without missing
xx = rand(1:10_000, 1_000_000)
int_fsort_timing = @belapsed fsort(xx)
int_missing_sort_timing = @belapsed sort(xx)

groupedbar(
    repeat(["1m Integer w missing", "1m Integer wo missing"], inner=2),
    [int_missing_sort_timing, int_missing_fsort_timing, int_missing_sort_timing, int_fsort_timing],
    group=repeat(["Base.sort", "SortingLab.fsort"], outer=2),
    title="Intger sort (1m rows): Base vs SortingLab")
savefig("benchmarks/int_1m_sort.png")


int_missing_fsortperm_timing = @belapsed fsortperm(x);
int_missing_sortperm_timing = @belapsed sortperm(x);

int_fsortperm_timing = @belapsed fsortperm(xx)
int_missing_sortperm_timing = @belapsed sortperm(xx)

groupedbar(
    repeat(["1m Integer w missing", "1m Integer wo missing"], inner=2),
    [int_missing_sortperm_timing, int_missing_fsortperm_timing, int_missing_sortperm_timing, int_fsortperm_timing],
    group=repeat(["Base.sort", "SortingLab.fsort"], outer=2),
    title="Intger sortperm (1m rows): Base vs SortingLab")
savefig("benchmarks/int_1m_sortperm.png")