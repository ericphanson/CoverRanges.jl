module CoverRanges
export CompInf, min_covering, solve_min_covering

include("access_dict.jl")
export AccessDict, total_gets, total_sets

# An object that is larger than any finite number
struct ComparisonInf end
const CompInf = ComparisonInf()
Base.isless(::ComparisonInf, ::ComparisonInf) = false

for T in (Int8, Int16, Int32, Int64, Int128) # add other types if needed
    @eval Base.isless(::ComparisonInf, ::$T) = false
    @eval Base.isless(::$T, ::ComparisonInf) = true
    @eval Base.:+(::$T, c::ComparisonInf) = c
    @eval Base.:+(c::ComparisonInf, ::$T) = c
end

# Corresponds to an instance of the problem (or subinstance)
struct LeftToCover{T}
    "Range to partially cover"
    r::UnitRange{T}
    "Number of nodes we are required to cover"
    K::T
end

# Corresponds to a solution (or part of one)
struct PartialCover{T}
    "Minimum number needed to partially cover the range"
    m::Union{T, ComparisonInf}
    "index of latest range added"
    i::Int
    "Key to point towards next range in the partial cover"
    key::LeftToCover{T}
end


"""
    find_furthest_range(a, C) -> index, right_endpoint

Given a node `a`, finds the range `r` in `C` such that `r` contains `a` and has
the largest right endpoint.
"""
function find_furthest_range(a, C)
    # This could be optimized more by sorting `C` first and terminating early
    best_f_so_far = typemin(a) # right endpoint
    best_i_so_far = nothing # index
    for (i, r) in enumerate(C)
        a ∈ r || continue
        if last(r) > best_f_so_far
            best_f_so_far = last(r)
            best_i_so_far = i
        end
    end
    return best_i_so_far, best_f_so_far
end


# We aim to solve the dynamic programming equation
# min_number_to_cover(a:b, K) = min(1 + min_number_to_cover(f:b, K - (f-a+1)), min_number_to_cover( (a+1):b, K))
# where min_number_to_cover(r, K) is the minimum number of ranges needed to cover at least `K` elements of `r`
# and `f` is the endpoint furthest to the right of any  range that includes `a`.
# Starting from the left, we reach node `a`. We can either include node `a` in our set of nodes covered, in which case we choose the range that includes `a` and stretches as far as possible to the right, and have to solve the problem on the remaining set of nodes (`f:b`, and we need to cover `K - (f-a+1))` nodes). Otherwise, we skip node `a` and need to solve the problem with the remaining nodes `a+1:b`, still needing to cover `K` nodes.
function min_covering(key::LeftToCover{T}, furthest_ranges, cache::AbstractDict{LeftToCover{T}, PartialCover{T}}) where {T}
    get!(cache, key) do
        r = key.r;  K = key.K
        K <= 0 && return PartialCover{T}(zero(T), 0, key)
        K > length(r) && return PartialCover{T}(CompInf, 0, key)
        a, b = first(r), last(r)
        i_a, f_a = furthest_ranges[a]
        skip_cover = min_covering(LeftToCover{T}(a+1:b, K), furthest_ranges, cache)
        i_a === nothing && return skip_cover
        add_key = LeftToCover{T}( (f_a+1) : b, K - (f_a - a + 1))
        add_cover = min_covering(add_key, furthest_ranges, cache)
        if add_cover.m + 1 <= skip_cover.m
            return PartialCover{T}(add_cover.m + T(1), i_a, add_key)
        else
            return skip_cover
        end
    end
end

"""
    solve_min_covering(r::UnitRange{T}, K, C; [cache]) -> Union{Nothing, Vector{Int}}

Returns either `nothing` or a vector of indices of `C` corresponding to a
minimal set of ranges which covers at least `K` elements of `r`. Returns
`nothing` if and only if the task is impossible.

* `r`: range to partially cover
* `K`: number of elements of `r` that must be
covered
* `C`: vector of ranges to use in constructing the partial cover
* `cache`: optionally provide an `AbstractDict{LeftToCover{T}, PartialCover{T}}`
which is used as a cache

!!! warning
    Overflow is not checked.
"""
function solve_min_covering(r::UnitRange{T}, K, C; cache =  Dict{LeftToCover{T},
PartialCover{T}}()) where {T}
    # `furthest_ranges` is all we need from `C`
    furthest_ranges = Dict(a => find_furthest_range(a, C) for a in r)

    # Recursive function to compute the covering
    result = min_covering(LeftToCover{T}(r, K), furthest_ranges, cache)

    k = result.m
    k == CompInf && return nothing

    # We store the list of ranges essentially as a linked list.
    # To recover the optimal list of ranges, we traverse through
    # the cache, at each step getting the `key` for the next element in the cache.
    range_inds = Int[]
    while k > 1
        push!(range_inds, result.i)
        k = result.m
        result = cache[result.key]
    end
    return range_inds
end

end # module
