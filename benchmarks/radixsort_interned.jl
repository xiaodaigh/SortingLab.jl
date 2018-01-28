using InternedStrings, SortingLab, DataFrames, StatsBase, BenchmarkTools
N = 20_000_000
K = 100
using RCall, CSV
using Plots

function compare_interned_string_sort(N, K)
    srand(1);
    @time samplespace = InternedString.("id".*dec.(1:N÷K, 10));

    # this is not the winner
    # function make_svec(N, samplespace)
    #     @time vss = rand(value.(samplespace), N)
    #     @time InternedString.(vss, true)
    # end

    @time svec = rand(samplespace, N);
    # @benchmark radixsort($svec)


    if false
        # show that it's working
        tic()
        @time aaa = radixsort(svec);
        2+2
        toc()
        # @time aaa1 = radixsort1(svec);
        issorted(aaa)
    end

    # interned_radixsort_timing = @belapsed radixsort($svec);
    interned_radixsort_timings = [@elapsed(radixsort(svec)) for i=1:5]
    interned_radixsort_timing = mean(interned_radixsort_timings)

    srand(1);
    @time samplespace1 = "id".*dec.(1:N÷K, 10);
    @time svec1 = rand(samplespace1,N);
    # @benchmark radixsort($svec1)

    # radixsort1_timing = @belapsed radixsort($svec1);
    radixsort1_timings = [@elapsed(radixsort(svec1)) for i=1:5]
    radixsort1_timing = mean(radixsort1_timings)
 
    r_timing = R"""
    memory.limit(40000)
    N=$N; K=$K
    res = NULL
    set.seed(1)
    system.time(d1 <- sample(sprintf("id%010d",1:(N/K)), N, T))
    for(i in 1:5) {
        pt = proc.time()
        system.time(sort(d1, method="radix"))
        2+2
        #data.table::timetaken(pt)
        pt2 = proc.time()
        gc()
        res = c(res, (pt2 - pt)[3])
    }
    res
    """

    df = DataFrame(
        contestant = ["InternedStrings.jl sort", "Julia radix sort", "R radix sort"],
        timing = [interned_radixsort_timing, radixsort1_timing, mean(r_timing)])

    CSV.write("benchmarks/interned_string_results/Interned Strings sort speed Julia vs R $(N÷1_000_000)m.csv", df)

    bar(
        df[:contestant], 
        df[:timing],
        title = "Interned Strings sort speed Julia vs R $(N÷1_000_000)m",
        label = "seconds")
    
    savefig("benchmarks/interned_string_results/Interned Strings sort speed Julia vs R $(N÷1_000_000)m.png")
end

# compare_interned_string_sort(1000,10)

@time compare_interned_string_sort.((1:10).*(10^8), 100)

# @time compare_interned_string_sort.((1:10).*(10^7), 100)