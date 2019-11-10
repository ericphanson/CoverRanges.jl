module CoverRanges #src
export CompInf, min_covering, solve_min_covering #src

include("access_dict.jl") #src
export AccessDict, total_gets, total_sets #src

# The idea of the algorithm is that we can simply start from the left-most element
# of the range `r` that we wish to cover, and decide whether or not to include it
# in our partial cover. If we do want to include it, the optimal range to use to
# cover it is the one which extends the furthest to the right (out of all the
# ranges which include the element). Then it remains to solve a smaller instance
# of the problem. Likewise, if we don't include the element, we again are left
# with a smaller instance of the problem. In other words, We aim to solve the
# dynamic programming equation `min_number_to_cover(a:b, K) = min(1 +
# min_number_to_cover(f:b, K - (f-a+1)), min_number_to_cover( (a+1):b, K))` where
# `min_number_to_cover(r, K)` is the minimum number of ranges needed to cover at
# least `K` elements of `r` and `f` is the endpoint furthest to the right of any
# range in `C` that includes `a`.

# We proceed starting from the left-most node (i.e. an element in the range). Let
# us say we reach node `a`. We can either

# * include node `a` in our set of nodes covered, in which case we choose the
#   range that includes `a` and stretches as far as possible to the right; in that
#   case, we have to solve the problem on the remaining set of nodes (this
#   corresponds to `min_number_to_cover(f:b, K - (f-a+1))`).
# * Otherwise, we skip node `a` and need to solve the problem with the remaining
# nodes `a+1:b`,
#   still needing to cover `K` nodes, which corresponds to `min_number_to_cover(
#   (a+1):b, K))`.


# We need an object to represent an impossible task, which is never chosen in a
# minimum and which is invariant under adding `+1`. Julia's `Inf` does this for
# us, but `Inf` is a floating point number, and we'd prefer to stick to integers
# (with the exception of this infinity).
struct ComparisonInf end
const CompInf = ComparisonInf()
Base.isless(::ComparisonInf, ::ComparisonInf) = false

for T in (Int8, Int16, Int32, Int64, Int128)
    @eval Base.isless(::ComparisonInf, ::$T) = false
    @eval Base.isless(::$T, ::ComparisonInf) = true
    @eval Base.:+(::$T, c::ComparisonInf) = c
    @eval Base.:+(c::ComparisonInf, ::$T) = c
end

# In the above list, we could add other types if needed, such as
# [SaferIntegers.jl](https://github.com/JeffreySarnoff/SaferIntegers.jl)
# numeric types to ensure our algorithm does not overflow.

# Next, we define an struct to hold an instance or subinstance of our problem.
struct LeftToCover{T}
    "Range to partially cover"
    r::UnitRange{T}
    "Number of nodes we are required to cover"
    K::T
end

# And likewise, one to hold a solution (or part of one).
struct PartialCover{T}
    "Minimum number needed to partially cover the range"
    m::Union{T, ComparisonInf}
    "Index of latest range added"
    i::Int
    "Key to point towards next range in the partial cover"
    key::LeftToCover{T}
end


# To find the range with the furthest right endpoint
# including a given node, we just write a simple loop.
"""
    find_furthest_range(a, C) -> index, right_endpoint

Given a node `a`, finds the range `r` in `C` such that `r` contains `a` and has
the largest right endpoint.
"""
function find_furthest_range(a, C)
    ## This could be optimized more by sorting `C` first and terminating early
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

# Now comes the heart of the algorithm. We compute
# `min_number_to_cover(a:b, K) = min(1 + min_number_to_cover(f:b, K - (f-a+1)), min_number_to_cover( (a+1):b, K))`
# recursively with the help of a memoization cache, which maps from
# (sub)instances of the problem to solutions.
function min_covering(key::LeftToCover{T}, furthest_ranges, cache::AbstractDict{LeftToCover{T}, PartialCover{T}}) where {T}
    get!(cache, key) do
        r = key.r;  K = key.K
        K <= 0 && return PartialCover{T}(zero(T), 0, key) # Nothing left to cover
        K > length(r) && return PartialCover{T}(CompInf, 0, key) # Impossible task
        a, b = first(r), last(r)
        i_a, f_a = furthest_ranges[a] # index and right endpoint of optimal range including `a`

        ## Solve the subproblem in which we skip `a`
        skip_cover = min_covering(LeftToCover{T}(a+1:b, K), furthest_ranges, cache)
        i_a === nothing && return skip_cover # cannot cover `a` means we must skip it

        ## Solve the subproblem in which we include `a` in our partial cover
        add_key = LeftToCover{T}( (f_a+1) : b, K - (f_a - a + 1))
        add_cover = min_covering(add_key, furthest_ranges, cache)

        ## Decide whether or not to include `a` and return the better result
        if add_cover.m + 1 <= skip_cover.m
            return PartialCover{T}(add_cover.m + T(1), i_a, add_key)
        else
            return skip_cover
        end
    end
end

# Note that in the case that we choose to skip `a`, we return `skip_cover`, which
# is the solution for the subproblem that skips `a`. But when we choose to include
# `a` in the partial cover, we make a new `PartialCover` object instead of
# returning `add_cover`. That's because if we include `a` by using the range that
# ends at `f_a`, we really are adding a range to the partial cover represented by
# `add_cover`, so we make a new `PartialCover` object, whose value of `m` is one
# larger (corresponding to the extra range we added), which holds the index `i_a`
# of the range that we added, and which holds `add_key`, which we can use to
# recover `add_cover` from `cache` later. In all, this lets us hold the sequence
# of ranges used in the final optimal cover efficiently, as a linked list.

# Now we wrap `min_covering` in a helper function that constructs `furthest_ranges`,
# the memoization cache, and unwinds the linked list that holds the solution in order
# to recover the indices of the ranges included in the minimal partial cover we have found.
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
which is used as a memoization cache

!!! warning
    Overflow is not checked.
"""
function solve_min_covering(r::UnitRange{T}, K, C; cache =  Dict{LeftToCover{T},
PartialCover{T}}()) where {T}
    ## `furthest_ranges` is all we need from `C`
    furthest_ranges = Dict(a => find_furthest_range(a, C) for a in r)

    ## Recursive function to compute the covering
    result = min_covering(LeftToCover{T}(r, K), furthest_ranges, cache)

    k = result.m # minimum number of ranges needed
    k == CompInf && return nothing

    ## We store the list of ranges essentially as a linked list.
    ## To recover the optimal list of ranges, we traverse through
    ## the cache, at each step getting the `key` for the next element in the cache.
    range_inds = Int[]
    sizehint!(range_inds, k)
    while k > 1
        push!(range_inds, result.i)
        k = result.m
        result = cache[result.key]
    end
    return range_inds
end

end #src
