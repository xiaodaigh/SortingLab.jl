---
author: "Dai ZJ"
title: "SortingLab README"
date: "2024--09-21"
---

# SortingLab
An alternative implementation of sorting algorithms and APIs. The ultimate aim is to contribute back to Julia base or SortingAlgorithms.jl. However, there is commitment to keep this package's API stable and supported, so other developers can rely on the implementation and API here.

# Faster Sort and Sortperm

The main function exported by SortingLab is `fsort` and `fsortperm` which generally implements faster algorithms than `sort` and `sortperm` for `CategoricalArrays.CategoricalVector`, `Vector{T}`,  `Vector{Union{String, Missing}}` where `T` is

**Update Sep'2024**: SortingLab.jl used to be faster than base on integer sorting which is no longer the case! Well done base!

**Note**: The reason why we restrict the type to `Vector` is that SortingLab.jl assumes something about memory layout and hence `Vector` provides that guarantee in the types supported.

## Usage

```julia
using SortingLab;
using Test
N = 1_000_000;
K = 100;

svec = rand("id".*string.(1:N÷K, pad=10), N);

svec_sorted = fsort(svec);
@test issorted(svec_sorted)
@test issorted(svec) == false
```

```
Test Passed
```



```julia
# faster string sortperm
sorted_idx = fsortperm(svec)
issorted(svec[sorted_idx]) #true

# in place string sort
fsort!(svec);
issorted(svec) # true
```

```
true
```



```julia
# CategoricalArray sort
using CategoricalArrays
pools = "id".*string.(1:100,3);
byvec = CategoricalArray{String, 1}(rand(UInt32(1):UInt32(length(pools)), N), CategoricalPool(pools, false));
byvec = compress(byvec);

byvec_sorted = fsort(byvec);
@test issorted(byvec_sorted)
```

```
Test Passed
```





### Sorting `Vector{Union{T, Missing}}`

For vectors that contain `missing`, the `sort` and `sortperm` performance is often sub-optimal in `Base` and is not supported in `SortingAlgorithms.jl`'s radixsort implementation. This is solved by `SortingLab.jl` `fsort`, see Benchmarks Section

```julia
using Test
using Missings: allowmissing
x = allowmissing(rand(1:10_000, 1_000_000))
x[rand(1:length(x), 100_000)] .= missing

using SortingLab
@test isequal(fsort(x), sort(x))
```

```
Test Passed
```






## Benchmarks
![Base.sort vs SortingLab.radixsort](benchmarks/sort_vs_radixsort.png)

#![Base.sort vs SortingLab.radixsort](benchmarks/sortperm_vs_fsortperm.png)

![Integer Base.sort vs SortingLab.fsort](benchmarks/int_1m_sort.png)

![Integer Base.sort vs SortingLab.fsort](benchmarks/int_1m_sortperm.png)

## Benchmarking code
```julia
using SortingLab;
using BenchmarkTools;
import Random: randstring
using Test
using Missings: allowmissing
using Plots, StatsPlots

N = 1_000_000;
K = 100;

# String Sort
svec = rand("id".*string.(1:N÷K, pad=10), N);
sort_id_1m = @belapsed sort($svec);
radixsort_id_1m = @belapsed radixsort($svec);

sortperm_id_1m = @belapsed sortperm($svec);
fsortperm_id_1m = @belapsed fsortperm($svec);

rsvec = rand([randstring(rand(1:32)) for i = 1:N÷K], N);
sort_r_1m = @belapsed sort($rsvec);
radixsort_r_1m = @belapsed radixsort($rsvec);

sortperm_r_1m = @belapsed sortperm($rsvec);
fsortperm_r_1m = @belapsed fsortperm($rsvec);


groupedbar(
    repeat(["IDs", "Random len 32"], inner=2),
    [sort_id_1m, radixsort_id_1m, sort_r_1m, radixsort_r_1m],
    group = repeat(["Base.sort","SortingLab.radixsort"], outer = 2),
    title = "Strings sort (1m rows): Base vs SortingLab")
savefig("benchmarks/sort_vs_radixsort.png")

groupedbar(
    repeat(["IDs", "Random len 32"], inner=2),
    [sortperm_id_1m, fsortperm_id_1m, sortperm_r_1m, fsortperm_r_1m],
    group = repeat(["Base.sortperm","SortingLab.fsortperm"], outer = 2),
    title = "Strings sortperm (1m rows): Base vs SortingLab")
savefig("benchmarks/sortperm_vs_fsortperm.png")
```

```
"C:\\git\\SortingLab\\benchmarks\\sortperm_vs_fsortperm.png"
```





# Similar package

https://github.com/JuliaCollections/SortingAlgorithms.jl

# Build status
[![Build Status](https://travis-ci.org/xiaodaigh/SortingLab.jl.svg?branch=master)](https://travis-ci.org/xiaodaigh/SortingLab.jl)

[![Coverage Status](https://coveralls.io/repos/xiaodaigh/SortingLab.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/xiaodaigh/SortingLab.jl?branch=master)

[![codecov.io](http://codecov.io/github/xiaodaigh/SortingLab.jl/coverage.svg?branch=master)](http://codecov.io/github/xiaodaigh/SortingLab.jl?branch=master)
