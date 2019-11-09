const AT{T} =  NamedTuple{(:get, :set),Tuple{T,T}}

struct AccessDict{KT, VT, T} <: AbstractDict{KT, VT}
    dict::Dict{KT, VT}
    access_dict::Dict{KT, AT{T}}
end

function AccessDict{T}(dict::Dict{KT, VT}) where {KT, VT, T}
    access_dict = Dict{KT, AT{T}}()
    return AccessDict{KT, VT, T}(dict, access_dict)
end

AccessDict(dict::Dict{KT, VT}) where {KT, VT} = AccessDict{Int}(dict)

AccessDict{KT, VT}() where {KT, VT} = AccessDict{Int}(Dict{KT, VT}())

Base.length(d::AccessDict) = length(d.dict)

Base.@propagate_inbounds Base.iterate(d::AccessDict) = iterate(d.dict)
Base.@propagate_inbounds Base.iterate(d::AccessDict, state) = iterate(d.dict,state)

function Base.get!(f::Base.Callable, d::AccessDict, key)
    if haskey(d.dict, key)
        (g, s) = d.access_dict[key]
        d.access_dict[key] = (get=g+1, set=s)
    else
        d.access_dict[key] = (get=0, set=1)
    end
    Base.get!(f, d.dict, key)
end


function Base.get(f::Base.Callable, d::AccessDict, key)
    if haskey(d.dict, key)
        (g, s) = d.access_dict[key]
        d.access_dict[key] = (get=g+1, set=s)
    end
    Base.get(f, d.dict, key)
end

Base.get(d::AccessDict, key, default) = get(() -> default, d, key)
Base.get!(d::AccessDict, key, default) = get!(() -> default, d, key)


total_gets(d::AccessDict) = sum( v -> v[2].get, d.access_dict)
total_sets(d::AccessDict) = sum( v -> v[2].set, d.access_dict)
