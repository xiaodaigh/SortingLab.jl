function fsort(x::AbstractVector{Union{String, Missing}}; rev = false)
    nmissing = sum(ismissing, x)
    cx = similar(x)
    cx[1:length(x) - nmissing] .= fsort(collect(skipmissing(x)); rev = rev)
    cx[length(x)+1:end] .= missing
    cx
end
