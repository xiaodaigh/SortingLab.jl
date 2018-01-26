using SortingLab;
using BenchmarkTools;

N = 100_000_000;
K = 100;

tic()
svec = rand("id".*dec.(1:N÷K, 10), N);
@time radixsort(svec);
sort_id_1m = @belapsed sort($svec);


sortperm_id_1m = @belapsed sortperm($svec);
fsortperm_id_1m = @belapsed fsortperm($svec);

rsvec = rand([randstring(rand(1:32)) for i = 1:N÷K], N);
sort_r_1m = @belapsed sort($rsvec);
radixsort_r_1m = @belapsed radixsort($rsvec);

sortperm_r_1m = @belapsed sortperm($rsvec);
fsortperm_r_1m = @belapsed fsortperm($rsvec);
toc()

tic()
using Plots
using StatPlots
groupedbar(
    repeat(["IDs", "random len 32","sortperm - IDs", "sortperm random len 32"], inner=2), 
    [sort_id_1m, radixsort_id_1m, sortperm_id_1m, fsortperm_id_1m, sort_r_1m, radixsort_r_1m, sortperm_r_1m, fsortperm_r_1m], 
    group = repeat(["Base","SortingLab.jl"], outer = 4),
    title = "Strings sorting perf (1m): Base.sort vs SortingLab.radixsort")
savefig("benchmarks/sort_vs_radixsort.png")
toc()