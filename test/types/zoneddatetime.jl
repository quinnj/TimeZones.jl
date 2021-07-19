using TimeZones: Transition
using Dates: Hour, Second, UTM, @dateformat_str

@testset "ZonedDateTime" begin
    utc = FixedTimeZone("UTC", 0, 0)
    warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))

    @testset "dateformat parsing" begin
        @testset "successful parsing: $f" for f in (parse, tryparse)
            # Make sure all dateformat codes parse correctly
            # yYmuUdHMSseEzZ and yyyymmdd
            zdt = ZonedDateTime(1, 2, 3, 4, 5, 6, 7, utc)
            # Test y, u, d, H, M, S, s, Z
            p_zdt = f(
                ZonedDateTime,
                "Feb 3 1, 4:5:6.007 UTC",
                dateformat"u d y, H:M:S.s Z",
            )
            @test zdt == p_zdt

            # Test m, e, Y, z
            p_zdt = f(
                ZonedDateTime,
                "2 mon 3 1, 4:5:6.007+00:00",
                dateformat"m e d Y, H:M:S.s+z",
            )
            @test zdt == p_zdt

            # Test E, U
            p_zdt = f(
                ZonedDateTime,
                "February Monday 3 1 4:5:6.007 UTC",
                dateformat"U E d y H:M:S.s Z",
            )
            @test zdt == p_zdt

            # Test yyyymmdd
            p_zdt = f(
                ZonedDateTime,
                "00010203 4:5:6.007 UTC",
                dateformat"yyyymmdd H:M:S.s Z",
            )
            @test zdt == p_zdt
        end

        @testset "failed parsing: parse" begin
            @test_throws ArgumentError parse(
                ZonedDateTime,
                "2015-07-29 11:12:13.456 FakeTZ",
                dateformat"yyyy-mm-dd HH:MM:SS.sss Z",
            )

            @test_throws ArgumentError parse(
                ZonedDateTime,
                "2015-07-29 11:12:13.456",
                dateformat"yyyy-mm-dd HH:MM:SS.sss Z",
            )
        end

        @testset "failed parsing: tryparse" begin
            @test tryparse(
                ZonedDateTime,
                "2015-07-29 11:12:13.456 FakeTZ",
                dateformat"yyyy-mm-dd HH:MM:SS.sss Z",
            ) === nothing

            @test tryparse(
                ZonedDateTime,
                "2015-07-29 11:12:13.456",
                dateformat"yyyy-mm-dd HH:MM:SS.sss Z",
            ) === nothing
        end
    end

    @testset "standard time" begin
        local_dt = DateTime(1916, 2, 1, 0)
        utc_dt = DateTime(1916, 1, 31, 23)

        # Disambiguating parameters ignored when there is no ambiguity.
        @test ZonedDateTime(local_dt, warsaw).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, 0).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, 1).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, 2).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, true).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, false).zone.name == "CET"
        @test ZonedDateTime(utc_dt, warsaw, from_utc=true).zone.name == "CET"

        @test ZonedDateTime(local_dt, warsaw).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 0).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 1).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 2).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, true).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, false).utc_datetime == utc_dt
        @test ZonedDateTime(utc_dt, warsaw, from_utc=true).utc_datetime == utc_dt
    end

    @testset "daylight saving time" begin
        local_dt = DateTime(1916, 6, 1, 0)
        utc_dt = DateTime(1916, 5, 31, 22)

        # Disambiguating parameters ignored when there is no ambiguity.
        @test ZonedDateTime(local_dt, warsaw).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, 0).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, 1).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, 2).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, true).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, false).zone.name == "CEST"
        @test ZonedDateTime(utc_dt, warsaw, from_utc=true).zone.name == "CEST"

        @test ZonedDateTime(local_dt, warsaw).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 0).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 1).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, 2).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, true).utc_datetime == utc_dt
        @test ZonedDateTime(local_dt, warsaw, false).utc_datetime == utc_dt
        @test ZonedDateTime(utc_dt, warsaw, from_utc=true).utc_datetime == utc_dt
    end

    @testset "spring-forward" begin
        local_dts = (
            DateTime(1916,4,30,22),
            DateTime(1916,4,30,23),
            DateTime(1916,5,1,0),
        )
        utc_dts = (
            DateTime(1916,4,30,21),
            DateTime(1916,4,30,22),
        )
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw)
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw, 0)
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw, 1)
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw, 2)
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw, true)
        @test_throws NonExistentTimeError ZonedDateTime(local_dts[2], warsaw, false)

        @test ZonedDateTime(local_dts[1], warsaw).zone.name == "CET"
        @test ZonedDateTime(local_dts[3], warsaw).zone.name == "CEST"
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).zone.name == "CET"
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).zone.name == "CEST"

        @test ZonedDateTime(local_dts[1], warsaw).utc_datetime == utc_dts[1]
        @test ZonedDateTime(local_dts[3], warsaw).utc_datetime == utc_dts[2]
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]
    end

    @testset "fall-back" begin
        local_dt = DateTime(1916, 10, 1, 0)
        utc_dts = (DateTime(1916, 9, 30, 22), DateTime(1916, 9, 30, 23))

        @test_throws AmbiguousTimeError ZonedDateTime(local_dt, warsaw)
        @test_throws AmbiguousTimeError ZonedDateTime(local_dt, warsaw, 0)

        @test ZonedDateTime(local_dt, warsaw, 1).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, 2).zone.name == "CET"
        @test ZonedDateTime(local_dt, warsaw, true).zone.name == "CEST"
        @test ZonedDateTime(local_dt, warsaw, false).zone.name == "CET"
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).zone.name == "CEST"
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).zone.name == "CET"

        @test ZonedDateTime(local_dt, warsaw, 1).utc_datetime == utc_dts[1]
        @test ZonedDateTime(local_dt, warsaw, 2).utc_datetime == utc_dts[2]
        @test ZonedDateTime(local_dt, warsaw, true).utc_datetime == utc_dts[1]
        @test ZonedDateTime(local_dt, warsaw, false).utc_datetime == utc_dts[2]
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]
    end

    @testset "standard offset reduced" begin
        # The zone's standard offset was changed from +2 to +1 creating an ambiguous hour
        local_dt = DateTime(1922,5,31,23)
        utc_dts = (DateTime(1922, 5, 31, 21), DateTime(1922, 5, 31, 22))
        @test_throws AmbiguousTimeError ZonedDateTime(local_dt, warsaw)

        @test ZonedDateTime(local_dt, warsaw, 1).zone.name == "EET"
        @test ZonedDateTime(local_dt, warsaw, 2).zone.name == "CET"
        @test_throws AmbiguousTimeError ZonedDateTime(local_dt, warsaw, true)
        @test_throws AmbiguousTimeError ZonedDateTime(local_dt, warsaw, false)
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).zone.name == "EET"
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).zone.name == "CET"

        @test ZonedDateTime(local_dt, warsaw, 1).utc_datetime == utc_dts[1]
        @test ZonedDateTime(local_dt, warsaw, 2).utc_datetime == utc_dts[2]
        @test ZonedDateTime(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
        @test ZonedDateTime(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]
    end

    @testset "2-hour daylight saving time offset" begin
        # Check behaviour when the "save" offset is larger than an hour.
        paris = first(compile("Europe/Paris", tzdata["europe"]))

        @test ZonedDateTime(DateTime(1945,4,2,1), paris).zone == FixedTimeZone("WEST", 0, 3600)
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(1945,4,2,2), paris)
        @test ZonedDateTime(DateTime(1945,4,2,3), paris).zone == FixedTimeZone("WEMT", 0, 7200)

        @test_throws AmbiguousTimeError ZonedDateTime(DateTime(1945,9,16,2), paris)
        @test ZonedDateTime(DateTime(1945,9,16,2), paris, 1).zone == FixedTimeZone("WEMT", 0, 7200)
        @test ZonedDateTime(DateTime(1945,9,16,2), paris, 2).zone == FixedTimeZone("CET", 3600, 0)

        # Ensure that dates are continuous when both a UTC offset and the DST offset change.
        @test ZonedDateTime(DateTime(1945,9,16,1), paris).utc_datetime == DateTime(1945,9,15,23)
        @test ZonedDateTime(DateTime(1945,9,16,2), paris, 1).utc_datetime == DateTime(1945,9,16,0)
        @test ZonedDateTime(DateTime(1945,9,16,2), paris, 2).utc_datetime == DateTime(1945,9,16,1)
        @test ZonedDateTime(DateTime(1945,9,16,3), paris).utc_datetime == DateTime(1945,9,16,2)
    end

    @testset "multiple hour transitions" begin
        # Transitions changes that exceed an hour. Results in having two sequential
        # non-existent hour and two sequential ambiguous hours.
        t = VariableTimeZone("Testing", [
            Transition(DateTime(1800,1,1), FixedTimeZone("TST",0,0)),
            Transition(DateTime(1950,4,1), FixedTimeZone("TDT",0,7200)),
            Transition(DateTime(1950,9,1), FixedTimeZone("TST",0,0)),
        ])

        # A "spring forward" where 2 hours are skipped.
        @test ZonedDateTime(DateTime(1950,3,31,23), t).zone == FixedTimeZone("TST",0,0)
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(1950,4,1,0), t)
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(1950,4,1,1), t)
        @test ZonedDateTime(DateTime(1950,4,1,2), t).zone == FixedTimeZone("TDT",0,7200)


        # A "fall back" where 2 hours are duplicated. Never appears to occur in reality.
        @test ZonedDateTime(DateTime(1950,8,31,23), t).utc_datetime == DateTime(1950,8,31,21)  # TDT

        # First occurrences of duplicated hours.
        @test ZonedDateTime(DateTime(1950,9,1,0), t, 1).utc_datetime == DateTime(1950,8,31,22) # TST
        @test ZonedDateTime(DateTime(1950,9,1,1), t, 1).utc_datetime == DateTime(1950,8,31,23) # TST

        # Second occurrences of duplicated hours.
        @test ZonedDateTime(DateTime(1950,9,1,0), t, 2).utc_datetime == DateTime(1950,9,1,0)   # TDT
        @test ZonedDateTime(DateTime(1950,9,1,1), t, 2).utc_datetime == DateTime(1950,9,1,1)   # TDT

        @test ZonedDateTime(DateTime(1950,9,1,2), t).utc_datetime == DateTime(1950,9,1,2)      # TDT
    end

    @testset "highly ambiguous hour" begin
        # Ambiguous local DateTime that has more than 2 solutions. Never occurs in reality.
        t = VariableTimeZone("Testing", [
            Transition(DateTime(1800,1,1), FixedTimeZone("TST",0,0)),
            Transition(DateTime(1960,4,1), FixedTimeZone("TDT",0,7200)),
            Transition(DateTime(1960,8,31,23), FixedTimeZone("TXT",0,3600)),
            Transition(DateTime(1960,9,1), FixedTimeZone("TST",0,0)),
        ])

        @test ZonedDateTime(DateTime(1960,8,31,23), t).utc_datetime == DateTime(1960,8,31,21)  # TDT
        @test ZonedDateTime(DateTime(1960,9,1,0), t, 1).utc_datetime == DateTime(1960,8,31,22) # TDT
        @test ZonedDateTime(DateTime(1960,9,1,0), t, 2).utc_datetime == DateTime(1960,8,31,23) # TXT
        @test ZonedDateTime(DateTime(1960,9,1,0), t, 3).utc_datetime == DateTime(1960,9,1,0)   # TST
        @test ZonedDateTime(DateTime(1960,9,1,1), t).utc_datetime == DateTime(1960,9,1,1)      # TST

        @test_throws AmbiguousTimeError ZonedDateTime(DateTime(1960,9,1,0), t, true)
        @test_throws AmbiguousTimeError ZonedDateTime(DateTime(1960,9,1,0), t, false)
    end

    @testset "skip an entire day" begin
        # Significant offset change: -11:00 -> 13:00.
        apia = first(compile("Pacific/Apia", tzdata["australasia"]))

        # Skips an entire day.
        @test ZonedDateTime(DateTime(2011,12,29,23),apia).utc_datetime == DateTime(2011,12,30,9)
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(2011,12,30,0),apia)
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(2011,12,30,23),apia)
        @test ZonedDateTime(DateTime(2011,12,31,0),apia).utc_datetime == DateTime(2011,12,30,10)
    end

    @testset "redundant transitions" begin
        # Redundant transitions should be ignored.
        # Note: that this can occur in reality if the TZ database parse has a Zone that ends
        # at the same time a Rule starts. When this occurs the duplicates always in standard
        # time with the same abbreviation.
        zone = Dict{AbstractString,FixedTimeZone}()
        zone["DTST"] = FixedTimeZone("DTST", 0, 0)
        zone["DTDT-1"] = FixedTimeZone("DTDT-1", 0, 3600)
        zone["DTDT-2"] = FixedTimeZone("DTDT-2", 0, 3600)

        dup = VariableTimeZone("DuplicateTest", [
            Transition(DateTime(1800,1,1), zone["DTST"])
            Transition(DateTime(1935,4,1), zone["DTDT-1"])  # Ignored
            Transition(DateTime(1935,4,1), zone["DTDT-2"])
            Transition(DateTime(1935,9,1), zone["DTST"])
        ])

        # Make sure that the duplicated hour only doesn't contain an additional entry.
        @test_throws AmbiguousTimeError ZonedDateTime(DateTime(1935,9,1), dup)
        @test ZonedDateTime(DateTime(1935,9,1), dup, 1).zone.name == "DTDT-2"
        @test ZonedDateTime(DateTime(1935,9,1), dup, 2).zone.name == "DTST"
        @test_throws BoundsError ZonedDateTime(DateTime(1935,9,1), dup, 3)

        # Ensure that DTDT-1 is completely ignored.
        @test_throws NonExistentTimeError ZonedDateTime(DateTime(1935,4,1), dup)
        @test ZonedDateTime(DateTime(1935,4,1,1), dup).zone.name == "DTDT-2"
        @test ZonedDateTime(DateTime(1935,8,31,23), dup).zone.name == "DTDT-2"
    end

    @testset "equality" begin
        # Check equality between ZonedDateTimes
        apia = first(compile("Pacific/Apia", tzdata["australasia"]))

        spring_utc = ZonedDateTime(DateTime(2010, 5, 1, 12), utc)
        spring_apia = ZonedDateTime(DateTime(2010, 5, 1, 1), apia)

        @test spring_utc.zone == FixedTimeZone("UTC", 0, 0)
        @test spring_apia.zone == FixedTimeZone("SST", -39600, 0)
        @test spring_utc == spring_apia
        @test spring_utc !== spring_apia
        @test isequal(spring_utc, spring_apia)
        @test hash(spring_utc) == hash(spring_apia)
        @test astimezone(spring_utc, apia) === spring_apia  # Since ZonedDateTime is immutable
        @test astimezone(spring_apia, utc) === spring_utc
        @test isequal(astimezone(spring_utc, apia), spring_apia)
        @test hash(astimezone(spring_utc, apia)) == hash(spring_apia)

        fall_utc = ZonedDateTime(DateTime(2010, 10, 1, 12), utc)
        fall_apia = ZonedDateTime(DateTime(2010, 10, 1, 2), apia)

        @test fall_utc.zone == FixedTimeZone("UTC", 0, 0)
        @test fall_apia.zone == FixedTimeZone("SDT", -39600, 3600)
        @test fall_utc == fall_apia
        @test fall_utc !== fall_apia
        @test !(fall_utc < fall_apia)
        @test !(fall_utc > fall_apia)
        @test isequal(fall_utc, fall_apia)
        @test hash(fall_utc) == hash(fall_apia)
        @test astimezone(fall_utc, apia) === fall_apia  # Since ZonedDateTime is immutable
        @test astimezone(fall_apia, utc) === fall_utc
        @test isequal(astimezone(fall_utc, apia), fall_apia)
        @test hash(astimezone(fall_utc, apia)) == hash(fall_apia)
    end

    @testset "broadcastable" begin
        # Validate that ZonedDateTime is treated as a scalar during broadcasting
        zdt = ZonedDateTime(2000, 1, 2, 3, utc)
        @test size(zdt .== zdt) == ()
    end

    @testset "deepcopy hash" begin
        # Issue #78
        x = ZonedDateTime(2017, 7, 6, 15, 44, 55, 28, warsaw)
        y = deepcopy(x)

        @test x == y
        @test x !== y
        @test !(x < y)
        @test !(x > y)
        @test isequal(x, y)
        @test hash(x) == hash(y)

        # Check that the ZonedDateTime and plain DateTimes don't hash to the same value.
        @test hash(x) != hash(y.utc_datetime)
    end

    @testset "multiple time zones" begin
        # ZonedDateTime constructor that takes any number of Period or TimeZone types
        @test_throws ArgumentError ZonedDateTime(FixedTimeZone("UTC", 0, 0), FixedTimeZone("TMW", 86400, 0))
    end

    @testset "cutoff" begin
        # The absolutely min DateTime you can create. Even smaller than `typemin(DateTime)`
        early_utc = ZonedDateTime(DateTime(UTM(typemin(Int64))), utc)

        # A FixedTimeZone is effective for all of time where as a VariableTimeZone has as
        # start.
        @test DateTime(early_utc, UTC) < warsaw.transitions[1].utc_datetime
        @test_throws NonExistentTimeError astimezone(early_utc, warsaw)
    end

    @testset "UnhandledTimeError" begin
        # VariableTimeZone with a cutoff set
        cutoff_tz = VariableTimeZone(
            "cutoff", [Transition(DateTime(1970, 1, 1), utc)], DateTime(1988, 5, 6),
        )

        ZonedDateTime(DateTime(1970, 1, 1), cutoff_tz)  # pre cutoff
        @test_throws UnhandledTimeError ZonedDateTime(DateTime(1988, 5, 6), cutoff_tz)  # on cutoff
        @test_throws UnhandledTimeError ZonedDateTime(DateTime(1989, 5, 7), cutoff_tz)
        @test_throws UnhandledTimeError ZonedDateTime(DateTime(1988, 5, 5), cutoff_tz) + Hour(24)

        zdt = ZonedDateTime(DateTime(2038, 3, 28), warsaw, from_utc=true)
        @test_throws UnhandledTimeError zdt + Hour(1)
    end

    @testset "no cutoff" begin
        # TimeZones that no longer have any transitions after the max_year shouldn't have a cutoff
        # eg. Asia/Hong_Kong, Pacific/Honolulu, Australia/Perth
        perth = first(compile("Australia/Perth", tzdata["australasia"]))
        zdt = ZonedDateTime(DateTime(2200, 1, 1), perth, from_utc=true)
    end

    @testset "convenience constructors" begin
        # Convenience constructors for making a DateTime on-the-fly
        digits = [2010, 1, 2, 3, 4, 5, 6]
        for i in eachindex(digits)
            @test ZonedDateTime(digits[1:i]..., warsaw) == ZonedDateTime(DateTime(digits[1:i]...), warsaw)
            @test ZonedDateTime(digits[1:i]..., utc) == ZonedDateTime(DateTime(digits[1:i]...), utc)
        end

        # Convenience constructor dealing with ambiguous time
        digits = [1916, 10, 1, 0, 2, 3, 4]  # Fall DST transition in Europe/Warsaw
        for i in eachindex(digits)
            expected = [
                ZonedDateTime(DateTime(digits[1:i]...), warsaw, 1)
                ZonedDateTime(DateTime(digits[1:i]...), warsaw, 2)
            ]

            if i > 1
                @test_throws AmbiguousTimeError ZonedDateTime(digits[1:i]..., warsaw)
            end

            @test ZonedDateTime(digits[1:i]..., warsaw, 1) == expected[1]
            @test ZonedDateTime(digits[1:i]..., warsaw, 2) == expected[2]
            @test ZonedDateTime(digits[1:i]..., warsaw, true) == expected[1]
            @test ZonedDateTime(digits[1:i]..., warsaw, false) == expected[2]
        end
    end

    @testset "promotion" begin
        @test_throws ErrorException promote_type(ZonedDateTime, Date)
        @test_throws ErrorException promote_type(ZonedDateTime, DateTime)
        @test_throws ErrorException promote_type(Date, ZonedDateTime)
        @test_throws ErrorException promote_type(DateTime, ZonedDateTime)
        @test promote_type(ZonedDateTime, ZonedDateTime) == ZonedDateTime

        # Issue #52
        dt = now()
        @test_throws ErrorException ZonedDateTime(dt, warsaw) > dt
    end

    @testset "extrema" begin
        @test typemin(ZonedDateTime) <= ZonedDateTime(typemin(DateTime), utc)
        @test typemax(ZonedDateTime) >= ZonedDateTime(typemax(DateTime), utc)
    end

    @testset "isbits(::ZonedDateTime)" begin
        # https://github.com/JuliaTime/TimeZones.jl/issues/271

        @testset "typeof($zone)" for zone in (tz"America/Winnipeg", FixedTimeZone("0123"))
            # We are not isbits until we fix the timezone to also be isbits
            zdt = ZonedDateTime(Date(2000), zone)
            if isbits(zone)
                @test isbits(zdt)
            else
                @test_broken isbits(zdt)
            end
        end
    end
end
