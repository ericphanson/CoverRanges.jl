using CoverRanges
using CoverRanges: LeftToCover, PartialCover
using Test


@testset "Impossible task" begin
    r = 1:5
    K = 5
    C = [1:4]
    @test solve_min_covering(r, K, C) === nothing
end


@testset "Simple example with type $T" for T in (Int64, Int32)
    r = T(1):T(6)
    K = T(6)
    C = [T(1):T(1), T(6):T(6), T(2):T(5), T(1):T(3), T(4):T(6)]
    @test Set(C[solve_min_covering(r, K, C)]) == Set([T(1):T(3), T(4):T(6)])
end

@testset "Simple example with negative numbers" begin
    r = -6:-1
    K = 6
    C = [-1:-1, -6:-6, -5:-2, -3:-1, -6:-4]
    @test Set(C[solve_min_covering(r, K, C)]) == Set([-3:-1, -6:-4])
end


function check_coverage(range_to_cover, ranges)
    num_covered = 0
    for node in range_to_cover
        num_covered += any( r -> node in r, ranges)
    end
    return num_covered
end


function make_random_subrange(r::UnitRange{T}) where {T}
    a, b = first(r), last(r)
    k = rand(a:b)
    l = k + abs(round(T, (length(r)/100)*randn()))
    k:l
end

@testset "Random examples of size $n" for n ∈ (50, 200, 500)
    r = -n:n
    C = [ make_random_subrange(r) for _ = 1:3n ]
    for K in round.(Int, [.2, .4, .8, 1] .* (2n))
        possible = check_coverage(r, C) >= K
        result = solve_min_covering(r, K, C)
        if !possible
            @test result === nothing
        else
            @test check_coverage(r, C[result]) >= K
        end
    end

end


@testset "AccessDict{$T}" for T in (Int16, Int32, Int64)
    n = 1000
    r = T(1):T(n)
    C = [ make_random_subrange(r) for _ = 1:2n ]
    K = round(T, .9*n)
    cache = AccessDict{LeftToCover{T}, PartialCover{T}}()
    solve_min_covering(r, K, C; cache=cache)
    @test total_sets(cache) == length(cache)
    @test total_gets(cache) <= length(cache)
end
