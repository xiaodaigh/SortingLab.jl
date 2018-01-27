**TL;DR**
My (unoptimized) interned string sorting in Julia is on par or slower than R's; but if you include garbage collection (gc) time (which R tries to hide from you; I will explain) and you sort a large (200m+) vector then Julia is faster.

# Interned String Sorting
Another holiday in Australia, another round of playing around with string sorting. This time I have been playing around with [InternedStrings.jl](https://github.com/oxinabox/InternedStrings.jl), which implements a form of string interning. R's data.table exploited R's string interning to make string sorting fast. So I wanted to see if Julia can receive a similar speedup using interned strings. 

## Pseudo-code
This is my high-level **pseudo code** for faster interned string sort

1. Let `pool` be the hashtable (or whatever data structure) that stores all the unique strings
2. Create a data-structure, `pool_fast_lookup`, based on `pool` such that it's easy to look up a string and its rank, e.g. a sorted vector of the unique strings
3. Let `svec` be the vector you wish to sort; for each element of `svec` look up its rank in `pool_fast_lookup` and keep a count in a vector, `cnts`, of how many of each rank there are
4. generate a vector that repeats the `i`th unique string `cnts[i]` times

Of course step 4 is a little bit of a cheat but if you need to sort something else along with `svec` then you can turn step 4 into an rearrangement algorithms easily.

## Caveats
The above pseudo-code seems quite easy to implement, but I found that step 3 is really slow to do if you use strings directly. E.g. `searchedsortedfirst(x, y)` is slowed for sorted a vector of strings `x`. So I have used its pointer to do the looked up which is much faster; but requires an additional step to make the sorted pointed back to strings. This pointer-to-string overhead can really slow down the algorithm; and part of the reason why for shorter length strings a strainght radix sort is faster.

Also I found creating `Vector{InternedString}` to be really slow so I have decided to return a `Vector{String}`,so it's note perfect.

As mentioned this algorithm is only faster than R for large vectors and if we include garbage collection (gc) time. I noticed that if for some reason Julia decides not to gc during my run then the code is 2x faster than R. But more often than not it will try to gc which results in significant porpotion of time spent in gc. R is tricky in that if you time its sort it will return quickly. But if you try to do something as simple as `2+2` it will spend a signiciant amount of time in gc, so I have decided to keep the elapsed time of the sort plus `2+2` in R to include the gc time, or R might have a small advantage there, given it's less unfront with gc.

Overall, the interned string sort is "on par" with R in terms of speed.

## What can improve things?
Faster string comparision will massively improve the speed, as I can just use the pseudo-code version without resorting to comparing pointers for speed.




