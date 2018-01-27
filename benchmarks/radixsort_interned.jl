using InternedStrings, SortingLab, DataFrames, StatsBase, BenchmarkTools
N = 10_000_000
K = 100

srand(1);
@time samplespace = InternedString.("id".*dec.(1:N÷K, 10));

# this is not the winner
# function make_svec(N, samplespace)
#     @time vss = rand(value.(samplespace), N)
#     @time InternedString.(vss, true)
# end

@time svec = rand(samplespace, N)

if false
    # show that it's working
    tic()
    @time aaa = radixsort(svec);
    2+2
    toc()
    # @time aaa1 = radixsort1(svec);
    issorted(aaa)
end

tic()
@time aaa = radixsort(svec);
2+2
toc()
# @time aaa1 = radixsort1(svec);
issorted(aaa)

# run it 5 times manually to get the results
# if you use @btime then it's likely to report the one with GC so not accurate
interned_radixsort_timing = @belapsed radixsort($svec);

@time radixsort(svec);

srand(1);
@time samplespace1 = "id".*dec.(1:N÷K, 10)
@time svec1 = rand(samplespace1,N);

tic()
radixsort1_timing = @belapsed radixsort($svec1);
2+2
toc()

using RCall

r_timing = R"""
memory.limit(40000)
N=2e8; K=100
set.seed(1)
system.time(d1 <- sample(sprintf("id%010d",1:(N/K)), N, T))
pt = proc.time()
system.time(sort(d1, method="radix"))
2+2
#data.table::timetaken(pt)
pt2 = proc.time()
rm(d1); gc()
pt2 - pt
"""

using Plots

bar(
    ["InternedStrings.jl sort", "Julia radix sort", "R radix sort"], 
    [interned_radixsort_timing, radixsort1_timing, r_timing[3]],
    title = "Interned Strings sort speed Julia vs R")
savefig("Interned Strings sort speed Julia vs R.png")

