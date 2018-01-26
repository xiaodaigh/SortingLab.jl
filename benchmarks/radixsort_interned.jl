using InternedStrings, SortingLab, DataFrames, StatsBase, BenchmarkTools
N = 100_000_000
K = 100

srand(1);
@time samplespace = InternedString.("id".*dec.(1:N÷K, 10));
@time svec = rand(samplespace,N);

@btime radixsort($svec);

# @time samplespace = InternedString.(["c","a","b"]);
# srand(1);
# @time svec = rand(samplespace,1000)

# @time aaa = radixsort(svec);
# issorted(aaa)


