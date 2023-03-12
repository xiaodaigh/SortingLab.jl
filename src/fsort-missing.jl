fsort(x::AbstractVector{Union{T, Missing}}; rev = false) where T = begin
    nmissing = sum(ismissing, x)
    cx = similar(x)
    cx[1:length(x) - nmissing] .= fsort(collect(skipmissing(x)); rev = rev)
    cx[length(x)+1:end] .= missing
    cx
end
