fsortperm(x::AbstractVector{Union{Missing, T}}) where T =  begin
    n_missing = mapreduce(ismissing, +, x)
    res = Vector{Int}(undef, length(x))
    res[1:length(x)-n_missing] .= fsortperm(collect(skipmissing(x)))
    
end
