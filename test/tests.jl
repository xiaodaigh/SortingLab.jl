using SortingLab
using Base.Test
using SortingAlgorithms
import SortingAlgorithms: load_bits

# write your own tests here
# @test 1 == 2
N = 1_000_000
K = 100
samplespace = "id".*dec.(1:N÷K,10);
srand(1)
svec = rand(samplespace, N);

using BenchmarkTools

# overall sorting is faster too
function ghi(svec)
    csvec = copy(svec)
    gc()
    @time a = @elapsed SortingLab.sort_spointer!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)

    csvec = copy(svec)
    gc()
    @time b = @elapsed SortingAlgorithms.sort!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)
    a,b
end
@time [ghi(svec) for i=repeat([4], outer=5)]

# sorting vectors shows sorttwo! is faster
function def(svec, skipbytes)
    vs = load_bits.(UInt, svec, skipbytes);
    csvec = copy(svec)
    gc()
    @time a = @elapsed SortingLab.sorttwo!(vs, csvec);

    vs = load_bits.(UInt, svec, skipbytes);
    csvec = copy(svec)
    gc()
    @time b = @elapsed SortingAlgorithms.sorttwo!(vs, csvec);
    a,b
end
@time [def(svec, i) for i=repeat([4], outer=5)]


# sorting pointers shows that sorttwo! is fasters
function abc(svec, skipbytes)
    vs = load_bits.(UInt, svec, skipbytes);
    # index = FastGroupBy.fcollect(length(vs));
    # csvec = copy(svec)
    csvec = pointer.(svec)
    gc()
    @time a = @elapsed SortingLab.sorttwo!(vs, csvec);

    vs = load_bits.(UInt, svec, skipbytes);
    # index = FastGroupBy.fcollect(length(vs));
    # csvec = copy(svec)
    csvec = pointer.(svec)
    gc()
    # b = @elapsed SortingLab.sorttwo_old!(vs, index);
    @time b = @elapsed SortingAlgorithms.sorttwo!(vs, csvec);
    a,b

    # csvec = copy(svec)
    # @time a = @elapsed SortingLab.sort_spointer!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)

    # csvec = copy(svec)
    # @time b = @elapsed SortingAlgorithms.sort!(csvec, 1, length(csvec), StringRadixSort, Base.Forward)
    # a,b
end

using Base.Threads
println(nthreads());

@time [abc(svec, i) for i=repeat([4], outer=2)]


csvec = [randstring(8) for i =1:100];
@time SortingLab.sort_spointer!(csvec, 1, length(csvec), StringRadixSort, Base.Forward);

csvec = [randstring(8) for i =1:100];
@time SortingAlgorithms.sort!(csvec, 1, length(csvec), StringRadixSort, Base.Forward);

lo = 1
hi = length(svec)

# [abc(svec) for i  = 1:20]
# 20-element Array{Tuple{Float64,Float64},1}:
#  (3.30447, 2.27538)
#  (1.56587, 2.38168)
#  (1.72477, 2.29592)
#  (1.51554, 2.19927)
#  (1.58114, 2.37205)
#  (1.67712, 2.27833)
#  (1.54081, 2.25543)
#  (1.6349, 2.38872)
#  (1.62107, 2.27291)
#  (1.60027, 2.393)
#  (1.5623, 2.34241)
#  (1.64421, 2.36433)
#  (1.65756, 2.29755)
#  (1.58756, 2.27567)
#  (1.6318, 2.37143)
#  (1.6035, 2.31926)
#  (1.58667, 2.42479)
#  (1.6024, 2.33549)
#  (1.58388, 2.39197)
#  (1.64123, 2.29582)

function count_missing(A::Vector{Union{Bool,Missing}})
    t, m = 0, 0
    @inbounds for v in A
        ismissing(v) && (m += 1; continue)
        v && (t += 1)
    end
    return t, length(A) - t - m, m
end

a = [missing, true, false]
x = rand(a, 2^31-1)

function basic_bench(x)
    [@elapsed(count_missing(x)) for i = ]
end



using BenchmarkTools
@benchmark count_missing(x);