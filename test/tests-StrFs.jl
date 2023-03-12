@time a = rand([randstring(rand(0:16)) for i in 1:100_000], 10_000_000);

@time as = StrF{16}.(a);

@time sort(as, alg=RadixSort) |> issorted

@time asb = radixsort(as, rev=true)
@test issorted(asb, rev=true)

@time asb = radixsort(as)
@test issorted(asb)
