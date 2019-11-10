# CoverRanges

[![Build Status](https://travis-ci.com/ericphanson/CoverRanges.jl.svg?branch=master)](https://travis-ci.com/ericphanson/CoverRanges.jl)
[![Codecov](https://codecov.io/gh/ericphanson/CoverRanges.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/ericphanson/CoverRanges.jl)

Our task is to partially covering a range of integers from a collection of
subranges. More specifically, given a range `r` (a `UnitRange`, i.e. integer spacing)
and a collection of ranges `C`, we aim to find the smallest subcollection of `C`
that covers at least `K` elements of `r`.

This problem was posed by Jakob Nissen in the random channel of the Julia slack,
and here I've implemented a dynamic programming algorithm made by Mathieu
Tanneau, which is partly based on the solution to the case when `K = length(r)` given
here: <https://stackoverflow.com/a/294419>.

The file `src/CoverRanges.jl` was written as a [Literate.jl](https://github.com/fredrikekre/Literate.jl)
file, and is rendered in Markdown as the last part of my blog post
[*Learning algorithmic techniques: dynamic programming*](https://ericphanson.com/blog/2019/learning-algorithmic-techniques-dynamic-programming/).

## Example

Let's consider `r = 1:6`, `C = [1:1, 2:5, 6:6, 1:3, 4:6]` and `K = 6`. This is
just the case of needing an 100% cover of the range. A naive greedy algorithm
might take the longest range `2:5`. But then to cover `1` and `6`, two more
ranges would be needed. Instead, the optimum is to take the two ranges of length
`3`, namely `1:3` and `4:6`.

```julia
julia> using CoverRanges

julia> r = 1:6
1:6

julia> C = [1:1, 2:5, 6:6, 1:3, 4:6];

julia> C[solve_min_covering(r, 6, C)]
2-element Array{UnitRange{Int64},1}:
 1:3
 4:6
```

We can see that's exactly what we get. Let's make it more interesting. We'll
tile two copies of `C` next to each other:

```julia
julia> append!(C, [r .+ 6 for r in C])
10-element Array{UnitRange{Int64},1}:
 1:1  
 2:5  
 6:6  
 1:3  
 4:6  
 7:7  
 8:11 
 12:12
 7:9  
 10:12
```

and let's take `r=1:12`. Now, if `K=8`, one can just take the two largest ranges:

```julia
julia> r = 1:12
1:12

julia> C[solve_min_covering(r, 8, C)]
2-element Array{UnitRange{Int64},1}:
 2:5 
 8:11
```

But for `K = 10`, we'll take the two length-3 ranges to cover the first six,
then the length 4 range to complete the partial cover:

```julia
julia> C[solve_min_covering(r, 10, C)]
3-element Array{UnitRange{Int64},1}:
 1:3 
 4:6 
 8:11
 ```

whereas for `K=11`, the best we can do is cover all 12 by four sets of length-3 ranges:

```julia
julia> C[solve_min_covering(r, 11, C)]
4-element Array{UnitRange{Int64},1}:
 1:3  
 4:6  
 7:9  
 10:12
```

This package also provides an `AccessDict` object, which is a dictionary that
keeps track of when its elements are retrieved or set. Note that only enough
methods are implemented for it to be used as a memoization cache in this
package; for other uses, more methods would likely be needed (e.g. `getindex`
and `setindex!`). This can help provide more detailed information about how the
algorithm works.

```julia
julia> using CoverRanges: LeftToCover, PartialCover

julia> cache = AccessDict{LeftToCover{Int}, PartialCover{Int}}()
AccessDict{LeftToCover{Int64},PartialCover{Int64},Int64} with 0 entries

julia> solve_min_covering(r, 11, C; cache = cache)
4-element Array{Int64,1}:
  4
  5
  9
 10

julia> total_gets(cache)
7

julia> total_sets(cache)
22
```
