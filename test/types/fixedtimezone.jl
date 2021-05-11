@testset "FixedTimeZone" begin
    @test FixedTimeZone("0123") == FixedTimeZone("UTC+01:23", 4980)
    @test FixedTimeZone("+0123") == FixedTimeZone("UTC+01:23", 4980)
    @test FixedTimeZone("-0123") == FixedTimeZone("UTC-01:23", -4980)
    @test FixedTimeZone("01:23") == FixedTimeZone("UTC+01:23", 4980)
    @test FixedTimeZone("+01:23") == FixedTimeZone("UTC+01:23", 4980)
    @test FixedTimeZone("-01:23") == FixedTimeZone("UTC-01:23", -4980)
    @test FixedTimeZone("01:23:45") == FixedTimeZone("UTC+01:23:45", 5025)
    @test FixedTimeZone("+01:23:45") == FixedTimeZone("UTC+01:23:45", 5025)
    @test FixedTimeZone("-01:23:45") == FixedTimeZone("UTC-01:23:45", -5025)
    @test FixedTimeZone("99:99:99") == FixedTimeZone("UTC+99:99:99", 362439)
    @test FixedTimeZone("UTC") == FixedTimeZone("UTC", 0)
    @test FixedTimeZone("UTC+00") == FixedTimeZone("UTC", 0)
    @test FixedTimeZone("UTC+1") == FixedTimeZone("UTC+01:00", 3600)
    @test FixedTimeZone("UTC-1") == FixedTimeZone("UTC-01:00", -3600)
    @test FixedTimeZone("UTC+01") == FixedTimeZone("UTC+01:00", 3600)
    @test FixedTimeZone("UTC-01") == FixedTimeZone("UTC-01:00", -3600)
    @test FixedTimeZone("UTC+0123") == FixedTimeZone("UTC+01:23", 4980)
    @test FixedTimeZone("UTC-0123") == FixedTimeZone("UTC-01:23", -4980)

    @test FixedTimeZone("+01") == FixedTimeZone("UTC+01:00", 3600)
    @test FixedTimeZone("-02") == FixedTimeZone("UTC-02:00", -7200)
    @test FixedTimeZone("+00:30") == FixedTimeZone("UTC+00:30", 1800)
    @test FixedTimeZone("-00:30") == FixedTimeZone("UTC-00:30", -1800)

    @test_throws ArgumentError FixedTimeZone("1")
    @test_throws ArgumentError FixedTimeZone("01")
    @test_throws ArgumentError FixedTimeZone("123")
    @test_throws ArgumentError FixedTimeZone("012345")
    @test_throws ArgumentError FixedTimeZone("0123:45")
    @test_throws ArgumentError FixedTimeZone("01:2345")
    @test_throws ArgumentError FixedTimeZone("01:-23:45")
    @test_throws ArgumentError FixedTimeZone("01:23:-45")
    @test_throws ArgumentError FixedTimeZone("01:23:45:67")
    @test_throws ArgumentError FixedTimeZone("UTC1")
    @test_throws ArgumentError FixedTimeZone("+1")
    @test_throws ArgumentError FixedTimeZone("-2")

    @testset "broadcastable" begin
        # Validate that FixedTimeZone is treated as a scalar during broadcasting
        fixed_tz = FixedTimeZone("UTC")
        @test size(fixed_tz .== fixed_tz) == ()
    end

    @testset "isbits" begin
        # We are not using ShortStrings on 32-bit due to hash being broken on 32-bit.
        # See https://github.com/JuliaString/MurmurHash3.jl/issues/12
        if Int === Int64
            @test isbits(FixedTimeZone("0123"))
        else
            @test_broken isbits(FixedTimeZone("0123"))
        end
    end
end
