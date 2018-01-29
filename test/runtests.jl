using SortingLab
using Base.Test

N = 100_000_000
K = 100

# categorical sort
using CategoricalArrays, BenchmarkTools
pools = "id".*dec.(1:100,3);
byvec = CategoricalArray{String, 1}(rand(UInt32(1):UInt32(length(pools)), N), CategoricalPool(pools, false));
# @benchmark byvec_sorted = fsort($byvec)
# @benchmark byvec_sorted = fsort($byvec)
byvec = compress(byvec);

@benchmark fsort($byvec) samples = 50 seconds = 120
# BenchmarkTools.Trial:
#   memory estimate:  1002.61 KiB
#   allocs estimate:  325
#   --------------
#   minimum time:     1.148 ms (0.00% GC)
#   median time:      1.588 ms (0.00% GC)
#   mean time:        1.829 ms (7.72% GC)
#   maximum time:     9.459 ms (67.31% GC)
#   --------------
#   samples:          2724
#   evals/sample:     1
@benchmark SortingLab.fsort2($byvec) samples = 50 seconds = 120

byvec_sorted = fsort(byvec);
@test issorted(byvec_sorted)

issorted(vec)


fsort!(byvec)
@test issorted(byvec)


# String sort
tic()
# const M=1000; const K=100; 
svec1 = rand([Base.randstring(rand(1:4)) for k in 1:N÷K], N);
@time res1 = radixsort(svec1)
@test issorted(res1)

# test sortperm
idx = fsortperm(svec1)
@test issorted(svec1[idx])

svec1 = rand([Base.randstring(rand(1:8)) for k in 1:N÷K], N);
@time res1 = radixsort(svec1)
@test issorted(res1)

# test sortperm
idx = fsortperm(svec1)
@test issorted(svec1[idx])

svec1 = rand([Base.randstring(rand(1:32)) for k in 1:N÷K], N);
@time res1 = radixsort(svec1)
@test issorted(res1)

@time res1 = radixsort(svec1, true)
@test issorted(res1, rev = true)

# test sortperm
idx = fsortperm(svec1)
@test issorted(svec1[idx])

@time sort!(svec1);
@test issorted(svec1)

svec1 = rand([string(rand(Char.(32:126), rand(1:8))...) for k in 1:N÷K], N);
@time radixsort!(svec1);
@test issorted(svec1)

svec1 = rand([string(rand(Char.(32:126), rand(1:16))...) for k in 1:N÷K], N);
@time radixsort!(svec1);
@test issorted(svec1)

svec1 = rand([string(rand(Char.(32:126), rand(1:24))...) for k in 1:N÷K], N);
@time radixsort!(svec1);
@test issorted(svec1)

svec1 = rand([string(rand(Char.(32:126), rand(1:32))...) for k in 1:N÷K], N);
@time radixsort!(svec1);
@test issorted(svec1)
toc()
