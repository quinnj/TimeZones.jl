# Test that TimeZones.jl can be safely used in a multithreaded environment.
# Note that the number of threads being used cannot be changed dynamically, so
# this test file spawns a new julia process running with multiple threads.

using Test

const program = """
using TimeZones
using Test

@assert Threads.nthreads() > 1 "This system does not support multiple threads, so the thread-safety tests cannot be run."

function create_zdt(year, month, day, tz_name)
    ZonedDateTime(DateTime(year, month, day), TimeZone(tz_name))
end
function cycle_zdts()
    return [
        try
            create_zdt(year, month, day, tz_name)
        catch e
            e isa Union{ArgumentError,NonExistentTimeError} || rethrow()
            nothing
        end
        for year in 2000:2020
        for month in 1:5
        for day in 10:15
        for tz_name in timezone_names()
    ]
end

const outputs = Channel(Inf)
@sync begin
    for _ in 1:15
        Threads.@spawn begin
            put!(outputs, cycle_zdts())
        end
    end
end
close(outputs)

const tzs = collect(outputs)

# Test that every Task produced the same result
allsame(x) = all(y -> y == first(x), x)
@test allsame(tzs)
"""

@info "Running Thread Safety tests"
@testset "Multithreaded TimeZone construction" begin
    run(`$(Base.julia_cmd()) -t8 --proj -E $(program)`)
end
