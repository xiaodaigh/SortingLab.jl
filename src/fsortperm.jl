function fsortperm(x)
    #@warn "SortingLab.jl: calling fsortperm does not confer an advantage as it's not optimsied for type $(T)"
    i = collect(1:length(x))
    sorttwo!(copy(x), i)
    i
end
