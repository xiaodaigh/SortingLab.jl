# this is a sorting algorithm where the thing to be sorted and an index is sorted
# by packing the two into a 64bit word
using Revise
using SortingAlgorithms, SortingLab
using InternedStrings

@time samplespace = InternedString.("id".*dec.(1:1_000_000, 10));
srand(1);
@time svec = rand(samplespace, 100_000_000);


# @time isvec = InternedString.(svec)

#@time SortingAlgorithms.sortperm(svec, alg=StringRadixSort); # 51-55
# @time sortperm(svec); # 228
# @time unsafe_load.(Ptr{UInt}.(pointer.(svec)) .+ 4);
# @time ptrx = Ptr{UInt}.(pointer.(svec));
# @time unsafe_load.(ptrx .+ 4);
@time fsortperm(["abc","def"]);

srand(1);
svec = rand(samplespace, 100_000_000);
fsortperm_timing = @elapsed ss = fsortperm(svec);
issorted(svec[ss])

srand(1);
svec = rand(samplespace, 100_000_000);
sa_timing = @elapsed ss = SortingAlgorithms.sortperm_radixsort(svec);
issorted(svec[ss])



using RCall

r_timing = R"""
ss = sprintf("id%010d",1:1e6)
x = sample(ss, 1e8, replace=T)
system.time(order(x, method="radix"))
"""[3]

srand(1);
svec = rand(samplespace, 100_000_000);
base_timing = @elapsed ss = SortingAlgorithms.sortperm(svec);
issorted(svec[ss])

using StatPlots

secs_bar = bar(["fsortperm", "SortingAlgorithms.jl (unmerged PR)", "Julia baase", "R radixsort"],
    [fsortperm_timing, sa_timing, base_timing, r_timing])


rela_bar = bar(["fsortperm", "SortingAlgorithms.jl (unmerged PR)", "Julia base", "R radixsort"],
    [fsortperm_timing/r_timing, sa_timing/r_timing, base_timing/r_timing, r_timing/r_timing],
    label="multiple of R timing", title="Sortperm (R's order) performance",
    yticks = [0,5,10,15,20,25,30,35,40])

savefig(rela_bar,"sortperm_perf.png")

plot(secs_bar, rela_bar)