fsortperm(x...;y...) = sortperm(x..., y...)

function fsortperm(x::AbstractArray{T}) where T <: AbstractString
    i = collect(1:length(x))
    sorttwo!(copy(x), i)
    i
end

function fsortperm(x::AbstractArray{T}) where {T<:CategoricalArray}
    i = collect(1:length(x))
    sorttwo!(copy(x), i)
    i
end
