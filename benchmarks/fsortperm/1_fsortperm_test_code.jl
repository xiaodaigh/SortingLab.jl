################################################################################
# setting up
################################################################################
using SortingLab, SortingAlgorithms, BenchmarkTools, Base.Threads
rangelen = 1_000_000;
minval = 1;
srand(1);
a = rand(UInt32(minval):UInt32(rangelen+minval-1), 100_000_000);
lo = 1;
hi = length(a);
RADIX_SIZE = 10;
include("src/fsortperm_dev_code.jl");

################################################################################
# Hybrid LSD and counting sort
# I have shown below that coutning sorts beats radix sort up to 2^11= 2048 unique values
# so it makes sense to create a better one
################################################################################

a[fsortperm_msd_hybrid(a, rangelen, minval, 10, sortcutoff = 2048)] |> issorted
a[fsortperm_msd_hybrid(a, rangelen, minval, 10, sortcutoff = -1)] |> issorted

@benchmark fsortperm_msd_hybrid($a, rangelen, minval, 10, sortcutoff = -1) samples = 5 seconds = 120
@benchmark fsortperm_msd_hybrid($a, rangelen, minval, 10, sortcutoff = 2048) samples = 5 seconds = 120

################################################################################
# Straight counting sort
################################################################################

if false
    function counting_vs_radix(n)
        a = rand(1:n, 100_000_000)
        (@belapsed(sortperm_int_range2($a, $n, 1)), @belapsed(sortperm_int_range_p1($a, $n, 1, 10)))
    end

    tic()
    res = [counting_vs_radix(n) for n in 2.^(2:20)]
    toc()

    using Plots
    plot([r[1] for r in res], title="Counting-sortperm vs Radix-sortperm (# of elements = 100m)", label = "Counting-sortperm",
        ylabel = "seconds", xlabel = "log_2(n) unique values", ylim = (0, 15))
    plot!([r[2] for r in res], label = "Radix-sortperm")
    plot!(xticks = (2:20))
    savefig("Counting-sortperm vs Radix-sortperm ( of elements = 100m).png")

    a = rand(1:1_000_000, 100_000_000)
    @time sortperm_int_range2(a, 1_000_000, 1)
    @code_warntype sortperm_int_range2(a, 1_000_000, 1)
    # @code_lowered sortperm_int_range2(a, 1_000_000, 1)
    # @code_typed sortperm_int_range2(a, 1_000_000, 1)
    # @code_llvm sortperm_int_range2(a, 1_000_000, 1)
    # @code_native sortperm_int_range2(a, 1_000_000, 1)

    @benchmark sortperm_int_range2($a, $rangelen, $minval)
end


################################################################################
# MSD sortperm
################################################################################
function fsortperm_msd(a, rangelen, minval, RADIX_SIZE;  sortcutoff = -1)
    # println(RADIX_SIZE," ", now())
    @assert 2^32 > rangelen
    @assert 2^32 >= length(a)
    vs = Vector{VT}(length(a))
    @inbounds for i in eachindex(a)
        vs[i] = Pair(UInt32(i),UInt32(a[i]))
    end
    # @time @inbounds vs = [Pair(UInt32(i),UInt32(ai)) for (i, ai) in enumerate(a)]

    iters = Int(ceil(log(2, rangelen)/RADIX_SIZE))
    @assert iters <= ceil(Integer, sizeof(typeof(vs[1].second))*8/RADIX_SIZE)

    _fsortperm_msd(vs, 1, length(vs), rangelen, minval, RADIX_SIZE, iters, sortcutoff = sortcutoff)
end

function _fsortperm_msd(vs, lo, hi, rangelen, minval, RADIX_SIZE, iters, ts = similar(vs); sortcutoff = -1)
    len = hi-lo+1
    if len  == 1
        return [Int(vs[lo].first)]
    elseif len <= sortcutoff
        vsv = vs[lo:hi]
        sort!(vsv, by = x->x.second)
        return [Int(vsi.first) for vsi in vsv]
    end

    RADIX_MASK = UInt32(1<<RADIX_SIZE-1)
    
    # Init
    bin = zeros(UInt32, 2^RADIX_SIZE)

    # Histogram for each element, radix
    @inbounds for i = lo:hi
        v = vs[i].second
        idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1
        @inbounds bin[idx] += 1
    end

    # Sort!
    
 
    # Unroll first data iteration, check for degenerate case
    v = vs[hi].second
    idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1

    # are all values the same at this radix?
    # if bin[idx,iters] == len;  continue;  end
    if bin[idx] == len
        if iters == 1
            return [Int(vsi.first) for vsi in vs[lo:hi]] 
        else
            return _fsortperm_msd(vs, lo, hi, rangelen, minval, RADIX_SIZE, iters-1, ts)
        end
    end

    # cbin = cumsum(bin[:])
    cbin  = copy(bin)
    cumsum!(bin, bin)
    cumsumbin = copy(bin)
    
    # Finish the loop...
    @inbounds for i in lo:hi
        ts[i] = vs[i]
    end

    @inbounds for i in lo:hi
        v = ts[i].second
        idx = Int((v >> (iters-1)*RADIX_SIZE) & RADIX_MASK) + 1
        ci = bin[idx]
        vs[lo - 1 + ci] = ts[i]
        bin[idx] -= 1
    end
    
    if iters == 1
        return [Int(vsi.first) for vsi in vs[lo:hi]]
    end

    # now that it's finished sorting sort each chunk recursive now
    res = Vector{Int}(length(vs))
    start_now = 1
    for i = 1:length(cumsumbin)
        if cbin[i] != 0
            res[start_now:cumsumbin[i]] = _fsortperm_msd(vs, start_now, cumsumbin[i], rangelen, minval, RADIX_SIZE, iters-1, ts)
            start_now = cumsumbin[i] + 1
        end
    end
    res
end

@time fsortperm_msd(a, rangelen, minval, 10)
@time fsortperm_msd(a, rangelen, minval, 10, sortcutoff = 64)

using RCall
@rput a
r = R"""
memory.limit(2^31-1)
system.time(order(a))
"""

srand(1);
a = rand((minval):(rangelen+minval-1), 1_000_000_000);
@benchmark fsortperm_msd($a, rangelen, minval, 10) samples = 5 seconds = 120
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 64) samples = 5 seconds = 120
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 2048)



srand(1)
a = rand(UInt32(minval):UInt32(rangelen+minval-1), 2^16);
vs = [Pair(UInt32(i),UInt32(ai)) for (i,ai) in enumerate(a)];
@btime fsortperm_msd($a, rangelen, minval, 10);
@btime sort($vs, by=x->x.second);

function test(n)
    srand(1);
    c = rand(UInt32(1):UInt32(1_000_000), n)
    vs = Vector{VT}(length(c))
    @inbounds for i in eachindex(c)
        vs[i] = Pair(UInt32(i),UInt32(c[i]))
    end

    res = [
    @belapsed(fsortperm_msd($c, 1_000_000, 1, 10, sortcutoff = -1)),
    @belapsed(sort($vs, by=x->x.second, alg = InsertionSort)),
    @belapsed(sort($vs, by=x->x.second))]
    res
end

hehe = test.(2.^(1:10))

using Plots
plot([h[1] for h in hehe])
plot!([h[2] for h in hehe])
plot!([h[3] for h in hehe])

@benchmark fsortperm_msd($a, rangelen, minval, 10) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 64) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 128) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 256) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 16) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 512) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 1024) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 10, sortcutoff = 2048) samples = 5 seconds = 30



@benchmark fsortperm_msd($a, rangelen, minval, 10) samples = 5 seconds = 30
@benchmark fsortperm_msd($a, rangelen, minval, 11) samples = 5 seconds = 30


b = a[as];
issorted(b)

################################################################################
# sorting algorithms from discourse
# https://discourse.julialang.org/t/ironic-observation-about-sort-and-sortperm-speed-for-small-intergers-vs-r/8715/20?u=xiaodai
################################################################################
# a = rand(1:1_000_000, 100_000_000)

@time sortperm_int_range_p1(a[1:1], rangelen, 1, 11);
gc()
@time sortperm_int_range_p1(a, rangelen, 1, 10);
gc()
@time sortperm_int_range_p1(a, rangelen, 1, 11);

@benchmark sortperm_int_range_p1(a, rangelen, 1, 10)

aint = Int.(a)
@benchmark sortperm_int_range_p1(aint, rangelen, 1, 10)
issorted(a[aa])

using RCall
@rput a

R"""
system.time(order(a))
"""

function bathtub(rangelen, minval, label, ontop)
    a = rand(UInt32(minval):UInt32(rangelen+minval-1), 100_000_000)
    res = [@elapsed sortperm_int_range_p1(a, rangelen, minval, i) for i = 1:20]
    if ontop
        plot!(res, label=label)
    else 
        plot(res, label=label)
    end
    res
end

using Plots
gc()
res1m = bathtub(1_000_000, 1, "1m", false)
res10k = bathtub(10_000, 1, "10k", true)
res2k = bathtub(2_000, 1, "2k", true)

df = DataFrame(res1m = res1m, res10k = res10k, res2k = res2k)
using CSV
# CSV.write("sortperm_int_range_p1 1 billion uniques (2k-1m).csv", df)

plot(res1m, label="1m", title = "sortperm_int_range_p1 1 billion uniques (2k-1m)")
plot!(res10k, label="10k")
plot!(res2k, label="2k")
# savefig("sortperm_int_range_p1 1 billion uniques (2k-1m).png")


################################################################################
# MSD sortperm in place
################################################################################
function fsortperm_msd_in_place(a, rangelen, minval, RADIX_SIZE)
    # println(RADIX_SIZE," ", now())
    @assert 2^32 > rangelen
    @assert 2^32 >= length(a)
    vs = Vector{VT}(length(a))
    @inbounds for i in eachindex(a)
        vs[i] = Pair(UInt32(i),UInt32(a[i]))
    end
    # @time @inbounds vs = [Pair(UInt32(i),UInt32(ai)) for (i, ai) in enumerate(a)]
    _fsortperm_msd_in_place(vs, rangelen, minval, RADIX_SIZE)
end

function _fsortperm_msd_in_place(vs, rangelen, minval, RADIX_SIZE)
    RADIX_MASK = UInt32(1<<RADIX_SIZE-1)

    # Init
    lo = 1
    hi = length(vs)
    iters = Int(ceil(log(2, rangelen)/RADIX_SIZE))
    
    # println("iters: $iters")
    @assert iters <= ceil(Integer, sizeof(typeof(vs[1].second))*8/RADIX_SIZE)
    bin = zeros(UInt32, 2^RADIX_SIZE, iters)

    # Histogram for each element, radix
    @inbounds for i = lo:hi
        v = vs[i].second
        for j = 1:iters
            idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
            @inbounds bin[idx,j] += 1
        end
    end

    # Sort!
    len = hi-lo+1
    done = BitArray(len)
    @inbounds for j = iters:iters
        done .= false
        # Unroll first data iteration, check for degenerate case
        v = vs[1].second
        idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1

        # are all values the same at this radix?
        if bin[idx,j] == len;  continue;  end

        cbin = cumsum(bin[:,j])

        # ci = cbin[idx]
        # ts[ci] = vs[hi]
        # cbin[idx] -= 1

        # Finish the loop...
        while !all(done)
            @inbounds for i in lo:hi
                if !done[i]
                    v = vs[i].second
                    idx = Int((v >> (j-1)*RADIX_SIZE) & RADIX_MASK) + 1
                    ci = cbin[idx]
                    vs[ci], vs[i] = vs[i], vs[ci]
                    # after the above swap vs[ci] is where is wants to be
                    done[ci] = true
                    cbin[idx] -= 1
                end
            end
            # println(sum(done))
        end
    end

    res = Vector{Int}(length(vs))
    @inbounds for i in eachindex(vs)
        res[i] = Int(vs[i].first)
    end
    res
    # [Int(vs1.first) for vs1 in vs]
end

@time fsortperm_msd_in_place(a, rangelen, minval, 11)

@code_warntype fsortperm_msd_in_place(a, rangelen, minval, 10)




################################################################################
# Staged counting sort
# this is a modified counting sort
################################################################################
function sortperm_int_range_p8(a, rangelen, minval, RADIX_SIZE)
    @assert 2^32 > rangelen
    @assert 2^32 >= length(a)
    vs::VTV = Vector{VT}(length(a))
    # vs = Vector{VT}(length(a))
    @inbounds for i in eachindex(a)
        vs[i] = Pair(UInt32(i),UInt32(a[i]))
    end
    _sortperm_int_range_p8(vs, rangelen, minval, RADIX_SIZE)
end

function _sortperm_int_range_p8(vs, rangelen, minval, RADIX_SIZE)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in vs
        cnts[ai.second - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    # note: this is for performance reasons only
    # do not change unless it's been benchmarked
    # creat a smaller sum
    iter, rem_iter = divrem(log(2,rangelen), RADIX_SIZE)
    step = Int(ceil(2^(rem_iter+RADIX_SIZE*(iter-1))))
    la = length(vs)
    res = Vector{Int}(la)

    for iter1 in 1:iter
        range = step:step:rangelen
        cnts_smaller = Vector{UInt32}(1 << RADIX_SIZE)
        for (i, rng) in enumerate(range)
            cnts_smaller[i] = cnts[rng]
        end
        last_index = Int(ceil(rangelen/step))
        cnts_smaller[last_index] = cnts[rangelen]

        # now distribute the cnts smaller according to the below cnts_smaller
        @inbounds for i in la:-1:1
            ai = Int(ceil((vs[i].second - minval + 1)/step))
            c = cnts_smaller[ai]
            cnts_smaller[ai] -= 1
            res[c] = i
        end
    end

    res
end

@time a1 = sortperm_int_range_p8(a, rangelen, minval, RADIX_SIZE)

(c1 |> diff .|> abs |> mean) |> round |> Int # 33 330 788 #33 333 154

# const RADIX_SIZE = 11
# if RADIX_SIZE < 9
#     const RADIX_MASK = UInt32(2<<(RADIX_SIZE-1)-1)
# elseif RADIX_SIZE < 17
#     const RADIX_MASK = UInt32(2<<(RADIX_SIZE-1)-1)
# else
#     const RADIX_MASK = UInt32(2<<(RADIX_SIZE-1)-1)
# end

################################################################################
# Straight counting sort mean travel distance
################################################################################
rangelen = 2000
minval = 1
a = rand(UInt32(minval):UInt32(rangelen+minval-1), 100_000_000)

function sortperm_int_range2c(a, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = zeros(Int, la)
    crecord = Vector{Int}(la)
    @inbounds for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1
        crecord[la-i+1] = c
        res[c] = i
    end

    res, crecord
end

@time a2, c2 = sortperm_int_range2c(a, rangelen, minval)

(c2 |> diff .|> abs |> mean) |> round |> Int # 33 328 745 # 33 333 180



################################################################################
# plotting the results
################################################################################
fsortperm_bench = @benchmark fsortperm(a)
using Plots
bar(
    ["Base.sortperm_int_range", "fsortperm", "R order(...)"],
    [17.218, fsortperm_bench.times./1e9 |> mean,  2.17 ],
    title = "`sortperm_int_range` perf (values = 1:1m, vector len = 100m)",
    ylabel="seconds"
)
savefig("julia_vs_r_sortperm_integer.png")



################################################################################
# proved that the res[c] is the problem statement in straight counting sort
# yes it's proven as I just removed that line but still sum counts and it completed
# very quickly
################################################################################
function prove_scs(a, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    # res = Vector{Int}(la)
    sumc = 0 
    @inbounds for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1
        # res[c] = i
        sumc += c
    end

    sumc
end

@benchmark prove_scs(a, rangelen, minval)
# BenchmarkTools.Trial:
#   memory estimate:  7.63 MiB
#   allocs estimate:  3
#   --------------
#   minimum time:     1.802 s (0.00% GC)
#   median time:      1.819 s (0.00% GC)
#   mean time:        1.879 s (0.03% GC)
#   maximum time:     2.018 s (0.00% GC)
#   --------------
#   samples:          3
#   evals/sample:     1


################################################################################
# yet to be classified
################################################################################
function sortperm_int_range7(a::Vector{T}, rangelen, minval) where T
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = Vector{Int}(la)

    upto = zero(UInt8)
    cache = zeros(Int, 256)

    jumptimes = 0 
    for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1

        upto += UInt8(1)
        # print(upto)
        if upto != 0
            cache[upto] = c
        else
            cache[256] = c
            res[cache] .= collect(la-jumptimes*256:-1:la-(jumptimes+1)*256+1)
        end
    end

    res
end
@time sortperm_int_range7(a, rangelen, minval)


function sortperm_int_range6(a::Vector{T}, rangelen, minval) where T
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = Vector{Int}(la)

    upto = zero(UInt8)
    cache = zeros(Int, 256, 2)

    for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1

        upto += UInt8(1)
        # print(upto)
        if upto != 0
            cache[upto, 1], cache[upto, 2] = c, i
        else
            cache[256, 1], cache[256,2] = c,i
            res[cache[:,1]] .= cache[:,2]
        end
    end

    res
end
@time sortperm_int_range6(a, rangelen, minval)

function sortperm_int_range5(a, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = Vector{Int}(la)

    upto = zeros(UInt8, rangelen)

    indexes = Array{Int, 2}(256, rangelen)

    @inbounds for i in 1:la
        ai = a[i] - minval + 1
        # c = cnts[ai]
        # cnts[ai] -= 1
        u = upto[ai]
        upto[ai] += 1
        indexes[u, ai] = i
    end

    indexes
end

@time sortperm_int_range5(a, rangelen, minval)

@time sortperm(a);
@time Base.Sort.sortperm_int_range(a, 999_999, 1);

function sortperm_int_range2(a, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for ai in a
        cnts[ai - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = length(a)
    res = Vector{Int}(la)
    @inbounds for i in la:-1:1
        ai = a[i] - minval + 1
        c = cnts[ai]
        cnts[ai] -= 1
        res[c] = i
    end

    res
end

rangelen = 1_000_000
minval = 1
@time x = sortperm_int_range2(a, 1_000_000, 1);
@code_warntype sortperm_int_range2(a, 1_000_000, 1);

reinterpret(Vector{UInt16}, 10)

a[x]
issorted(a[x])
using SortingLab
i = collect(1:length(a))
@time SortingLab.sorttwo!(a, i)

function sortperm_int_range3(a)
    ca = copy(a)
    i = collect(1:length(ca))
    SortingLab.sorttwo!(ca, i)
    i
end

@time ii = sortperm_int_range3(a)
issorted(a[ii])

using BenchmarkTools
@benchmark sortperm_int_range2(a, 1_000_000, 1) samples = 5 seconds = 120
# BenchmarkTools.Trial:
#   memory estimate:  770.57 MiB
#   allocs estimate:  4
#   --------------
#   minimum time:     15.931 s (0.00% GC)
#   median time:      16.970 s (0.00% GC)
#   mean time:        17.218 s (0.00% GC)
#   maximum time:     18.552 s (0.00% GC)
#   --------------  samples:          5
#   evals/sample:     1
@benchmark sortperm_int_range3(a) samples = 5 seconds = 120
# BenchmarkTools.Trial:
#   memory estimate:  2.99 GiB
#   allocs estimate:  557
#   --------------
#   minimum time:     10.916 s (0.00% GC)
#   median time:      13.304 s (3.02% GC)
#   mean time:        12.914 s (2.89% GC)
#   maximum time:     14.062 s (6.70% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

function sortperm_int_range4(a, minval)
    ula = UInt32(length(a))
    lz = leading_zeros(ula)

    ca = Vector{UInt64}(ula)

    tz = trailing_zeros(UInt64(minval))

    # ltz = lz - tz
    for i = UInt32(1):ula
        ca[i] = (UInt64(a[i]) << 32) | i
    end
    
    SortingLab.sort32!(ca, skipbits = 32+tz)

    Int.(ca .& (UInt64(2)^(32-lz)-1))
end

using SortingAlgorithms, BenchmarkTools, SortingLab

const a = rand(1:1_000_000, 100_000_000)
function test1(a)
    ca = (UInt32.(a) .<< 32) .| collect(UInt(1):UInt(length(a)))
    SortingLab.sort32!(ca)
end
@time test1(a)

@time x=sortperm_int_range4(a, 1);
@code_warntype test1(a);
issorted(a[x])





@benchmark sortperm_int_range4($a,1) samples = 5 seconds = 120
# BenchmarkTools.Trial:
#   memory estimate:  2.24 GiB
#   allocs estimate:  20
#   --------------
#   minimum time:     6.899 s (1.16% GC)
#   median time:      7.528 s (4.39% GC)
#   mean time:        7.508 s (3.58% GC)
#   maximum time:     8.004 s (4.13% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

using StatPlots

bar(
    ["sortperm_int_range", "my sortperm_int_range4", "R order(...)"],
    [17.218, 9.577, 2.17 ],
    title = "`sortperm_int_range` perf (values = 1:1m, vector len = 100m)",
    ylabel="seconds"
)
savefig("julia_vs_r_sortperm_integer.png")

@time aa = sortperm_int_range4(a, 1_000_000, 1)
issorted(a[aa])


a = rand(1:1_000_000, 100_000_000)


js = @elapsed sort(a)
jsp = @elapsed sortperm(a)

using RCall
@rput a
r = R"""
list(system.time(sort(a)),  system.time(order(a)))
"""

using StatPlots

groupedbar(
    ["sort", "sort", "sortperm", "sortperm"],
    [js, r[1][3], jsp, r[2][3]],
    group = ["Julia","R","Julia","R"],
    title = "Julia vs R sort and perm (values = 1:1m, vector len = 100m)",
    ylabel="seconds"
)
savefig("julia_vs_r_sortandperm_integer.png")

Got it!!! Almost there. Thanks to @sdanisch for this discussion. I have simply repurposed the code. Basically, I am using sort to create fsortperm which on par with R now! I am sure my code is pretty bad and that’s why it doesn’t beat R!!

@tshort, in a sense you are right, using sort seems to be the key, but basically, I have used Julia underlying counting sort to get this sort of performance. I still don’t understand why my original version is so slow as it’s just an application of counting sort (one pass radix sort).

julia_vs_r_sortperm_integerjulia_vs_r_sortperm_integer.png3600x2400 66.9 KB
See code below

# function fsortperm(a::Integer)
#     A2 = transpose(hcat(a, collect(1:length(a))))
#     Atup = reinterpret(NTuple{2, Int}, A2, (size(A2, 2),));
#     sort!(Atup)
#     [atup[2] for atup in Atup]
# end

# @time i = fsortperm(a)
# issorted(a[i]) # true

# fsortperm_bench = @benchmark fsortperm(a)
# using Plots
# bar(
#     ["Base.sortperm_int_range", "fsortperm", "R order(...)"],
#     [17.218, fsortperm_bench.times./1e9 |> mean,  2.17 ],
#     title = "`sortperm_int_range` perf (values = 1:1m, vector len = 100m)",
#     ylabel="seconds"
# )
# savefig("julia_vs_r_sortperm_integer.png")



@benchmark sort($a)
a32 = Int32.(a)

@benchmark sort($a32)

A2 = transpose(hcat(a, collect(1:length(a))))

ai = hcat(a, collect(1:length(a)))
function tshort1(ai, rangelen, minval)
    cnts = fill(0, rangelen)

    # create a count first
    @inbounds for i in 1:size(ai,1)
        cnts[ai[i,1] - minval + 1] +=  1
    end

    # create cumulative sum
    cumsum!(cnts, cnts)

    la = size(ai,1)
    res = Vector{Int}(la)
    aic = similar(ai)
    @inbounds for i in la:-1:1
        ai1 = ai[i,1] - minval + 1
        c = cnts[ai1]
        cnts[ai1] -= 1
        aic[c,:] .= ai[i,:]
    end

    aic
end


################################################################################
# failed ideas
################################################################################

@time tshort1(ai, 1_000_000, 1)
@code_warntype tshort1(ai, 1_000_000, 1)

Atup = reinterpret(NTuple{2, Int}, A2, (size(A2, 2),));

@time Atup_sorted = sort(Atup, by = x->x[1]);
@time Atup_sorted = sort!(Atup, by = x->x[1], alg=RadixSort)


sort(Atup; alg=QuickSort)

@benchmark sort(Atup)
@benchmark sort(Atup; alg=QuickSort)
@benchmark sort(Atup; alg=RadixSort)

# https://discourse.julialang.org/t/faster-sorting-with-gpu/8409/22?u=xiaodai
using SortingAlgorithms
function fsortperm(a::Vector{Int})
    @time A2 = transpose(hcat(a, collect(1:length(a))))
    @time Atup = reinterpret(NTuple{2, Int}, A2, (size(A2, 2),));
    @time sort!(Atup, by = x->x[1], alg=RadixSort)
    @time [atup[2] for atup in Atup]
end

@time fsortperm(a)

a = rand(1:1_000_000, 100_000_000)

using DataFrames
df = DataFrame(a = a, i = collect(1:length(a)))
@time abc(df) = sort!(df, cols = :a)
@time abc(df)

@time i = fsortperm(a)
issorted(a[i])[1]

ra = rand(Int, 100_000_000);
@time ira = fsortperm(ra); 
issorted(ra[ira]) # 29.0015

@time sortperm(ra); # 51