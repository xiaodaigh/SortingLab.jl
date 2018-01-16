function maxlength(svec, lo = 1, hi = length(svec))
    if lo > hi 
        return -1
    end
    ml = length(svec[lo])
    for i = lo+1:hi
        ml = max(ml, length(svec[i]))
    end
    ml
end

const CHAR0 = UInt8(0)
function code_unit0(str, pos)
    @inbounds return sizeof(str) < pos ? CHAR0 : codeunit(str, pos)
end

# inspiration http://www.cs.princeton.edu/courses/archive/spring03/cs226/lectures/radix
# radix 8 bytes at a time because 8 bytes fit into a word
function three_way_radix_qsort!(svec, lo = 1, hi = length(svec), skipbytes = 0, lb = UInt[])
    if hi <= lo
        # println("terminate")
        return svec
    elseif hi - lo == 1
        if svec[lo] > svec[hi]
            svec[lo], svec[hi] = svec[hi], svec[lo]
        end
        return svec
    elseif hi - lo < 16
        svec = sort!(svec, lo, hi, InsertionSort, Base.Forward)
        return svec
    end

    #  pick a pivot 
    # choose median
    

    # cmppos the position of letter to compare

    # i is the lower cursor, j is the upper cursor
    # p, q is used to keep track of equal elements in 4 way partition
    i, p = lo-1, lo
    j, q = hi+1, hi
    
    

    if length(lb) == 0
        # lb[lo:hi] = FastGroupBy.load_bits.(UInt, @view(svec[lo:hi]), skipbytes)
        lb = FastGroupBy.load_bits.(UInt, svec, skipbytes)
    end

    pivotl = sort!(lb[rand(lo:hi,3)])[2]

    # after this loop the data should have been partition 4 ways
    while i < j
        while true
            i += 1
            lb[i] < pivotl || break
        end        
        while true            
            j -= 1
            pivotl < lb[j] || break     
            
            if j == lo
                break;
            end
        end
        if i > j
            break;
        end
        # swap them now
        svec[i], svec[j] = svec[j], svec[i]
        lb[i], lb[j] = lb[j], lb[i]
        if lb[i] == pivotl
            svec[p], svec[i] = svec[i], svec[p]
            lb[p], lb[i] = lb[i], lb[p]
            p += 1
        end
        if lb[j] == pivotl        
            svec[q], svec[j] = svec[j], svec[q]
            lb[q], lb[j] = lb[j], lb[q]
            q -= 1
        end        
    end

    # if all elements are equal on that position then sort again
    if p >= q
        # println("p >= q")
        if FastGroupBy.maxlength(svec, lo, hi) > skipbytes + 8
            lb[lo:hi] = FastGroupBy.load_bits.(UInt, @view(svec[lo:hi]), skipbytes+8)
            three_way_radix_qsort!(svec, lo, hi, skipbytes + 8, lb)
            return svec
        end
    end

    # @show svec
    # println(string(p:q),pivotl,string(j:i),"lo:Hi",string(lo,hi))
    
    if lb[i] < pivotl 
        i += 1
    end

    for k = lo:p-1
        svec[k], svec[j] = svec[j], svec[k]
        lb[k], lb[j] = lb[j], lb[k]
        j -= 1
    end

    for k = hi:-1:q+1
        svec[k], svec[i] = svec[i], svec[k]
        lb[k], lb[i] = lb[i], lb[k]
        i += 1
    end

    # recursive sort

    # println("lessthan: ", lo,j,cmppos)
    three_way_radix_qsort!(svec, lo, j, skipbytes, lb)
    

    if i == hi && lb[i] == pivotl
        i += 1
    end
    if FastGroupBy.maxlength(svec, j+1, i-1) > skipbytes + 8 
        # println("mid: ", j+1,i-1,cmppos+1)
        lb[j+1:i-1] = FastGroupBy.load_bits.(UInt, @view(svec[j+1:i-1]), skipbytes+8)
        three_way_radix_qsort!(svec, j+1, i-1, skipbytes + 8, lb) # need to compute lb again
    end
    
    # println("gt: ", i,hi,cmppos+1)
    three_way_radix_qsort!(svec, i, hi, skipbytes, lb)
    
    return svec
end
