using SortingAlgorithms
using RCall
using StatPlots, DataFrames
using SortingLab, BenchmarkTools
using CSV
using Plots

function string_sort_vs_r(N, K)
    samplespace = "id".*dec.(1:N÷K,10)
    srand(1);
    svec = rand(samplespace, N);
    fsortperm_timing = @belapsed ss = fsortperm($svec);
    # @assert issorted(svec[ss])

    radixsort_timing = @belapsed radixsort($svec);

    r_timing = R"""
    memory.limit(40000)
    ss = sprintf("id%010d",1:$(N/K))
    x = sample(ss, $N, replace=T)
    st = system.time(order(x, method="radix"))
    rm(x); rm(ss); gc()
    st
    """[3]

    r_timing_sort = R"""
    memory.limit(40000)
    ss = sprintf("id%010d",1:$(N/K))
    x = sample(ss, $N, replace=T)
    st = system.time(sort(x, method="radix"))
    rm(x); rm(ss); gc()
    st
    """[3]
    
    DataFrame(N = N, K = K, fsortperm_timing = fsortperm_timing, 
    radixsort_timing=radixsort_timing, r_timing=r_timing, 
    r_timing_sort=r_timing_sort)
end

#warm up
string_sort_vs_r(1000, 10)


# @time a = string_sort_vs_r(10_000_000, 1)

# @time  for k in [2, 4, 10, 20, 50, 100, 200, 500, 1000]
#     a = vcat(a, string_sort_vs_r(10_000_000, k))
#     print(a)
# end
# CSV.write("string_sort_vs_r.csv", a)


@time b = string_sort_vs_r(100_000_000, 1)

@time  for k in [2, 4, 10, 20, 50, 100, 200, 500, 1000]
    b = vcat(b, string_sort_vs_r(100_000_000, k))
    print(b)
end

CSV.write("string_sort_vs_r_100m.csv", b)

# load the data and plot them
a = CSV.read("string_sort_vs_r.csv")
plot(a[:N]./a[:K], a[:radixsort_timing], 
title="Id Strings Vector (10m) sorting perf by # of uniques", 
ylabel="seconds",
label="Julia",
xlabel="# of uniques")
plot!(a[:N]./a[:K], a[:r_timing_sort], label="R")
savefig("string_sort_vs_r_10m.png")

a = CSV.read("string_sort_vs_r_100m.csv")
plot(a[:N]./a[:K], a[:radixsort_timing], 
title="Id Strings Vector (100m) sorting perf by # of uniques", 
ylabel="seconds",
label="Julia",
xlabel="# of uniques")
plot!(a[:N]./a[:K], a[:r_timing_sort], label="R")
savefig("string_sort_vs_r_100m.png")