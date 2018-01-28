using Revise;
using SortingLab;

N = 100_000_000;
K = 100;

svec = rand("id".*dec.(1:N÷K, 10), N);

@time svec_sorted = radixsort(svec, false, (22, 0x3fffff));
issorted(svec_sorted) # true

@time svec_sorted = radixsort(svec, false, (11, 0x7ff));
issorted(svec_sorted) # true

@time svec_sorted = radixsort(svec); # 16； fastest
issorted(svec_sorted) # true


function quirkysort(svec)
    fsortperm()