using InternedStrings, SortingLab, DataFrames, StatsBase, BenchmarkTools
N = 200_000_000
K = 100

srand(1);
@time samplespace = InternedString.("id".*dec.(1:N÷K, 10));

function make_svec1(N, samplespace)
    rand(samplespace, N)
end

value(s) = s.value

function make_svec2(N, samplespace)
    @time vss = rand(value.(samplespace), N)
    @time InternedString.(vss, true)
end

function make_svec3(N, samplespace)
    @time vss = rand(value.(samplespace), N)
    @time svec = Vector{InternedString}(N)
    @time for i =1:N
        svec[i].value = vss[1]
    end
    svec
end

# @time make_svec(N, samplespace);
@time make_svec2(N, samplespace);

@time svec = make_svec3(N, samplespace);
too slow
using ProgressMeter
function newis(N, rid, samplespace)
    svec = Vector{InternedString}(N)
    p = Progress(N, 1)
    vss = value.(samplespace)
    for i = 1:N
        svec[i] = InternedString(vss[rid[i]], true)
        next!(p)
    end
    svec
end

@time make_svec1(N, samplespace);
@time make_svec2(N, samplespace); # winner
@time svec = make_svec3(N, samplespace); # doesn't even run