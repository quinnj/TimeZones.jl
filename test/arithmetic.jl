using Dates: Day, Hour

warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))

normal = DateTime(2015, 1, 1, 0)   # a 24 hour day in warsaw
spring = DateTime(2015, 3, 29, 0)  # a 23 hour day in warsaw
fall = DateTime(2015, 10, 25, 0)   # a 25 hour day in warsaw

# Unary plus
@test +ZonedDateTime(normal, warsaw) == ZonedDateTime(normal, warsaw)

# Period arithmetic
@test ZonedDateTime(normal, warsaw) + Day(1) == ZonedDateTime(normal + Day(1), warsaw)
@test ZonedDateTime(spring, warsaw) + Day(1) == ZonedDateTime(spring + Day(1), warsaw)
@test ZonedDateTime(fall, warsaw) + Day(1) == ZonedDateTime(fall + Day(1), warsaw)

@test ZonedDateTime(normal, warsaw) + Hour(24) == ZonedDateTime(normal + Hour(24), warsaw)
@test ZonedDateTime(spring, warsaw) + Hour(24) == ZonedDateTime(spring + Hour(25), warsaw)
@test ZonedDateTime(fall, warsaw) + Hour(24) == ZonedDateTime(fall + Hour(23), warsaw)

# Do the same calculations but backwards over the transitions.
@test ZonedDateTime(normal + Day(1), warsaw) - Day(1) == ZonedDateTime(normal, warsaw)
@test ZonedDateTime(spring + Day(1), warsaw) - Day(1) == ZonedDateTime(spring, warsaw)
@test ZonedDateTime(fall + Day(1), warsaw) - Day(1) == ZonedDateTime(fall, warsaw)

@test ZonedDateTime(normal + Day(1), warsaw) - Hour(24) == ZonedDateTime(normal, warsaw)
@test ZonedDateTime(spring + Day(1), warsaw) - Hour(23) == ZonedDateTime(spring, warsaw)
@test ZonedDateTime(fall + Day(1), warsaw) - Hour(25) == ZonedDateTime(fall, warsaw)

# Ensure that arithmetic around transitions works.
@test ZonedDateTime(spring, warsaw) + Hour(1) == ZonedDateTime(spring + Hour(1), warsaw)
@test ZonedDateTime(spring, warsaw) + Hour(2) == ZonedDateTime(spring + Hour(3), warsaw)
@test ZonedDateTime(fall, warsaw) + Hour(2) == ZonedDateTime(fall + Hour(2), warsaw, 1)
@test ZonedDateTime(fall, warsaw) + Hour(3) == ZonedDateTime(fall + Hour(2), warsaw, 2)

# Non-Associativity
explicit_hour_day = (ZonedDateTime(spring, warsaw) + Hour(24)) + Day(1)
explicit_day_hour = (ZonedDateTime(spring, warsaw) + Day(1)) + Hour(24)
implicit_hour_day = ZonedDateTime(spring, warsaw) + Hour(24) + Day(1)
implicit_day_hour = ZonedDateTime(spring, warsaw) + Day(1) + Hour(24)

@test explicit_hour_day == ZonedDateTime(2015, 3, 31, 1, warsaw)
@test explicit_day_hour == ZonedDateTime(2015, 3, 31, 0, warsaw)
@test implicit_hour_day == ZonedDateTime(2015, 3, 31, 0, warsaw)
@test implicit_day_hour == ZonedDateTime(2015, 3, 31, 0, warsaw)

# CompoundPeriod canonicalization interacting with period arithmetic. Since `spring_zdt` is
# a 23 hour day this means adding `Day(1)` and `Hour(23)` are equivalent.
spring_zdt = ZonedDateTime(spring, warsaw)
@test spring_zdt + Day(1) + Minute(1) == spring_zdt + Hour(23) + Minute(1)

# When canonicalization happens automatically `Hour(24) + Minute(1)` is converted into
# `Day(1) + Minute(1)`. Fixed in `JuliaLang/julia#19268`
@test spring_zdt + Hour(23) + Minute(1) < spring_zdt + Hour(24) + Minute(1)

# Arithmetic with a StepRange should always work even when the start/stop lands on
# ambiguous or non-existent DateTimes.
@testset "StepRange{<:ZonedDateTime}" begin
    @testset "time-period" begin
        dt = DateTime(2015, 6, 1)

        results = Hour(1) .+ StepRange(
            ZonedDateTime(dt - Hour(1), warsaw),
            Hour(1),
            ZonedDateTime(dt - Hour(0), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(dt + Hour(0), warsaw),
            Hour(1),
            ZonedDateTime(dt + Hour(1), warsaw),
        )
        @test results == expected
        @test length(results) == 2
        @test results isa StepRange{<:ZonedDateTime}
    end

    @testset "date-period" begin
        dt = DateTime(2015, 6, 1)

        results =  Day(1) .- StepRange(
            ZonedDateTime(dt + Day(1), warsaw),
            Hour(1),
            ZonedDateTime(dt + Day(1) + Hour(1), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(dt, warsaw),
            Hour(1),
            ZonedDateTime(dt + Hour(1), warsaw),
        )
        @test results == expected
        @test length(results) == 2
        @test results isa StepRange{<:ZonedDateTime}
    end

    @testset "ambiguous" begin
        ambiguous = DateTime(2015, 10, 25, 2)   # Ambiguous hour in Warsaw

        results = Day(1) .+ StepRange(
            ZonedDateTime(ambiguous - Day(1) - Hour(1), warsaw),
            Hour(1),
            ZonedDateTime(ambiguous - Day(1), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(ambiguous - Hour(1), warsaw, 1),
            Hour(1),
            ZonedDateTime(ambiguous, warsaw, 2),
        )
        @test results == expected
        @test length(results) == 3
        @test results isa StepRange

        results = Day(1) .+ StepRange(
            ZonedDateTime(ambiguous - Day(1), warsaw),
            Hour(1),
            ZonedDateTime(ambiguous - Day(1) + Hour(1), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(ambiguous, warsaw, 1),
            Hour(1),
            ZonedDateTime(ambiguous + Hour(1), warsaw),
        )
        @test results == expected
        @test length(results) == 3
        @test results isa StepRange
    end

    @testset "non-existent" begin
        nonexistent = DateTime(2014, 3, 30, 2)  # Non-existent hour in Warsaw

        results = Day(1) .+ StepRange(
            ZonedDateTime(nonexistent - Day(1) - Hour(1), warsaw),
            Hour(1),
            ZonedDateTime(nonexistent - Day(1), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(nonexistent - Hour(1), warsaw),
            Hour(1),
            ZonedDateTime(nonexistent - Hour(1), warsaw),
        )
        @test results == expected
        @test length(results) == 1
        @test results isa StepRange

        results = Day(1) .+ StepRange(
            ZonedDateTime(nonexistent - Day(1), warsaw),
            Hour(1),
            ZonedDateTime(nonexistent - Day(1) + Hour(1), warsaw),
        )
        expected = StepRange(
            ZonedDateTime(nonexistent + Hour(1), warsaw),
            Hour(1),
            ZonedDateTime(nonexistent + Hour(1), warsaw),
        )
        @test results == expected
        @test length(results) == 1
        @test results isa StepRange
    end
end
