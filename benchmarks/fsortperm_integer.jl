using Revise
using SortingLab
using Base.Test, BenchmarkTools

N = 100_000_000
K = 100

# test fsortperm
a = rand(1:Int(N/K), N);
ca = copy(a);
@code_warntype fsortperm(a)
@benchmark fsortperm($a) samples = 5 seconds  = 20
# @code_warntype SortingLab.fsortperm_int_range_counting_sort(a, Int(N/K), 1)

# @code_warntype SortingLab.fsortperm_msd_hybrid(a, Int(N/K), 1, 10)
# @code_warntype SortingLab.fsortperm_msd_hybrid(a, Int(N/K), 1, 10, 1024)
# @code_warntype SortingLab.fsortperm_int_range_lsd(a, Int(N/K), 1, 10)

@time ab = fsortperm(a);
@test ca == a
@test issorted(a[ab])

@time aba = SortingLab.fsortperm_int_range_lsd(a, Int(N/K), 1, 10)

a2 = rand(1:2048, N);
@time a2b = SortingLab.fsortperm(a2);
issorted(a2[a2b])

@time a2b = SortingLab.fsortperm(a2, rev = true);
issorted(a2[a2b], rev = true)

@benchmark fsortperm($a2) samples = 5 seconds  = 20

a2 = rand(1:500, N);
@time a2b = SortingLab.fsortperm(a2);
@benchmark fsortperm($a2) samples = 5 seconds  = 20

@time SortingLab.fsortperm_int_range_counting_sort(a2, 2048, 1)

@benchmark SortingLab.fsortperm_int_range_counting_sort($a2, 2048, 1)

# @time SortingLab.fsortperm_msd_hybrid(a, Int(N/K), 1, 10)
# @time SortingLab.fsortperm_msd_hybrid(a, Int(N/K), 1, 10, 1024)
# @time SortingLab.fsortperm_int_range_lsd(a, Int(N/K), 1, 10)

@benchmark SortingLab.fsortperm_msd_hybrid($a, Int(N/K), 1, 10) samples = 5 seconds = 15
@benchmark SortingLab.fsortperm_msd_hybrid($a, Int(N/K), 1, 10, 1024) samples = 5 seconds = 15
@benchmark SortingLab.fsortperm_msd_hybrid($a, Int(N/K), 1, 10, 2048) samples = 5 seconds = 15
@benchmark SortingLab.fsortperm_int_range_lsd($a, Int(N/K), 1, 10) samples = 5 seconds = 15


@benchmark fsortperm_msd_hybrid($a, Int(N/K), 1, 10) seconds = 3600
# BenchmarkTools.Trial:
#   memory estimate:  3.74 GiB
#   allocs estimate:  12711                                                                                      
#   --------------
#   minimum time:     2.069 s (8.46% GC)                                                                        
#   mean time:        2.334 s (17.08% GC)                                                                        
#   --------------                                                                                              
#   evals/sample:     1  
@benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 1024) seconds = 3600
@benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 2048) seconds = 3600
@benchmark fsortperm_int_range_lsd($a, 1_000_000, 1, 10) seconds = 3600

@benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10) samples = 5 seconds = 15
@benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 1024) samples = 5 seconds = 15
@benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 2048) samples = 5 seconds = 15
@benchmark fsortperm_int_range_lsd($a, 1_000_000, 1, 10) samples = 5 seconds = 15
# BenchmarkTools.Trial:
#   memory estimate:  3.74 GiB
#   allocs estimate:  12711
#   --------------
#   minimum time:     2.448 s (10.43% GC)
#   median time:      2.530 s (15.98% GC)
#   mean time:        2.532 s (15.69% GC)
#   maximum time:     2.668 s (18.73% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

# Main> @benchmark fsortperm_int_range_lsd($a, 1_000_000, 1, 10) samples = 5 seconds = 15
# BenchmarkTools.Trial:
#   memory estimate:  2.24 GiB
#   allocs estimate:  13
#   --------------
#   minimum time:     2.256 s (0.49% GC)
#   median time:      2.399 s (9.61% GC)
#   mean time:        2.394 s (9.05% GC)
#   maximum time:     2.530 s (13.07% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

# Main> @benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 1024) samples = 5 seconds = 15
# BenchmarkTools.Trial:
#   memory estimate:  4.85 GiB
#   allocs estimate:  17599
#   --------------
#   minimum time:     2.595 s (8.32% GC)
#   median time:      2.795 s (14.35% GC)
#   mean time:        2.770 s (14.73% GC)
#   maximum time:     2.904 s (17.48% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

# Main> @benchmark fsortperm_msd_hybrid($a, 1_000_000, 1, 10, 2048) samples = 5 seconds = 15
# BenchmarkTools.Trial:
#   memory estimate:  4.85 GiB
#   allocs estimate:  17599
#   --------------
#   minimum time:     2.592 s (7.99% GC)
#   median time:      2.779 s (15.41% GC)
#   mean time:        2.762 s (15.46% GC)
#   maximum time:     2.902 s (20.23% GC)
#   --------------
#   samples:          5
#   evals/sample:     1