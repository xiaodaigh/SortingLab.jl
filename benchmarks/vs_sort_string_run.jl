include("benchmarks/vs_sort_code.jl")

using SortingLab;
using BenchmarkTools, DataFrames, CSV, Plots, StatPlots
using RCall;
N = 1_000_000;
K = 100;
randomseed = 1;

tic()
string_sort_perf(N, 100)
read_string_sort_perf_plot(N)
toc()

for N in Int.(10.^(7:8))
    string_sort_perf.(N, 100)
    read_string_sort_perf_plot(N)
end