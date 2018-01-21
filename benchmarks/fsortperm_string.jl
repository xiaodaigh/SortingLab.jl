# this is a sorting algorithm where the thing to be sorted and an index is sorted
# by packing the two into a 64bit word
using Revise
using SortingAlgorithms, SortingLab

samplespace = "id".*dec.(1:1_000_000, 10);
srand(1);
svec = rand(samplespace, 100_000_000);
#@time SortingAlgorithms.sortperm(svec, alg=StringRadixSort); # 51-55
# @time sortperm(svec); # 228
# @time unsafe_load.(Ptr{UInt}.(pointer.(svec)) .+ 4);
# @time ptrx = Ptr{UInt}.(pointer.(svec));
# @time unsafe_load.(ptrx .+ 4);
@time fsortperm(["abc","def"]);

@time ss = fsortperm(svec);
issorted(svec[ss])

@time ss = SortingAlgorithms.sortperm_radixsort(svec);
issorted(svec[ss])

aa = svec[ss]
