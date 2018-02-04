using SortingLab;
using BenchmarkTools, DataFrames, CSV, Plots, StatPlots
using RCall, IterTools, uCSV

function string_sort_and_perm_vs_r(svec)
    sort_id = @benchmark sort($svec)
    sortperm_id = @benchmark sortperm($svec)

    radixsort_id = @benchmark radixsort($svec)
    fsortperm_id = @benchmark fsortperm($svec)

    @rput svec;

    r_timing = R"""
    memory.limit(40000)
    res = NULL
    for(i in 1:$(length(radixsort_id.times))) {
        pt = proc.time()
        system.time(sort(svec, method="radix"))
        pt2 = proc.time()
        gc()
        res = c(res, (pt2 - pt)[3])
    }

    resorder = NULL
    for(i in 1:$(length(fsortperm_id.times))) {
        pt = proc.time()
        system.time(order(svec, method="radix"))
        pt2 = proc.time()
        gc()
        resorder = c(resorder, (pt2 - pt)[3])
    }
    rm(svec);gc()
    list(res, resorder)
    """
    sort_id, sortperm_id, radixsort_id, fsortperm_id, r_timing
end

sortperf2timings(x) = vcat([mean(x[i].times)/1e9 for i=1:4], [mean(x[5][1]), mean(x[5][2])])


function string_sort_perf(N, K, randomseed = 1)
    tic()
    srand(randomseed);
    svec = rand("id".*dec.(1:N÷K, 10), N);
    @time id_timings = string_sort_and_perm_vs_r(svec);
    
    srand(randomseed);
    fstr_samplespace = [randstring(8) for i = 1:N÷K];
    fsvec = rand(fstr_samplespace, N);
    @time fstr_timings = string_sort_and_perm_vs_r(fsvec)
   
    srand(randomseed);
    rstr_samplespace = [randstring(rand(1:8)) for i = 1:N÷K];
    rsvec = rand(rstr_samplespace, N);
    @time rstr_timings = string_sort_and_perm_vs_r(rsvec);
    toc()
    
    timings = reduce(vcat, sortperf2timings.([id_timings, fstr_timings, rstr_timings]))
    labels1 = ["IDs", "fixed len 8", "var len 8"]
    labels2 = ["sort", "sortperm"]
    labels3 = ["Julia Base", "Julia SortingLab.jl", "R"]
    
    group = repeat(labels3,  inner = 2, outer = 3)
    xlabel = repeat(labels1, inner = 6)
    sort_or_perm = repeat(labels2, outer = 9)

    df  = DataFrame(timings = timings, group = group, xlabel = xlabel, sort_or_perm = sort_or_perm, N = repeat([N], inner = 18), K = repeat([K], inner = 18))
    fileout = "string_sort_perf_$(N÷1_000_000)m.csv"
    CSV.write(fileout, df)
end

function read_string_sort_perf_plot(N)
    df = CSV.read("string_sort_perf_$(N÷1_000_000)m.csv")

    df1 = df[(df[:sort_or_perm] .== "sort") .& (df[:group] .!= "R"),:]
    gb1 = groupedbar(
        df1[:xlabel], 
        df1[:timings],
        group = df1[:group],
        ylabel = "seconds",
        title = "Base.sort vs SortingLab.radixsort ($(N÷1_000_000)m)")
    savefig(gb1, "benchmarks/sort_vs_radixsort_$(N÷1_000_000)m.png")

    df2 = df[(df[:sort_or_perm] .== "sort") .& (df[:group] .!= "R"),:]
    gb2 = groupedbar(
        df2[:xlabel], 
        df2[:timings],
        group = df2[:group],
        ylabel = "seconds",
        title = "Base.sortperm vs SortingLab.fsortperm ($(N÷1_000_000)m)")
    savefig(gb2, "benchmarks/sortperm_vs_fsorperm_$(N÷1_000_000)m.png")
end