using TimeZones.TZData: parse_components
using TimeZones: Transition

dt = DateTime(1942,12,25,1,23,45)
custom_dt = DateTime(1800,1,1)

utc = FixedTimeZone("UTC")
gmt = FixedTimeZone("GMT", 0)
foo = FixedTimeZone("FOO", 0)
null = FixedTimeZone("", 10800)
fixed = FixedTimeZone("UTC+01:00")
est = FixedTimeZone("EST", -18000)
warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))
apia = cache_tz(compile("Pacific/Apia", tzdata["australasia"]))
honolulu = cache_tz(compile("Pacific/Honolulu", tzdata["northamerica"]))  # Uses cutoff
ulyanovsk = first(compile("Europe/Ulyanovsk", tzdata["europe"]))  # No named abbreviations
new_york = first(compile("America/New_York", tzdata["northamerica"]))  # Underscore in name
custom = VariableTimeZone("Test/Custom", [Transition(custom_dt, utc)])  # Non-cached variable time zone

@test sprint(print, utc) == "UTC"
@test sprint(print, gmt) == "GMT"
@test sprint(print, foo) == "FOO"
@test sprint(print, null) == "UTC+03:00"
@test sprint(print, fixed) == "UTC+01:00"
@test sprint(print, est) == "EST"
@test sprint(print, warsaw) == "Europe/Warsaw"
@test sprint(print, apia) == "Pacific/Apia"
@test sprint(print, honolulu) == "Pacific/Honolulu"
@test sprint(print, ulyanovsk) == "Europe/Ulyanovsk"
@test sprint(print, custom) == "Test/Custom"

@test sprint(show_compact, utc) == "tz\"UTC\""
@test sprint(show_compact, gmt) == "tz\"GMT\""
@test sprint(show_compact, foo) == "FixedTimeZone(\"FOO\", 0)"
@test sprint(show_compact, null) == "FixedTimeZone(\"\", 10800)"
@test sprint(show_compact, fixed) == "tz\"UTC+01:00\""
@test sprint(show_compact, est) == "tz\"EST\""
@test sprint(show_compact, warsaw) == "tz\"Europe/Warsaw\""
@test sprint(show_compact, apia) == "tz\"Pacific/Apia\""
@test sprint(show_compact, honolulu) == "tz\"Pacific/Honolulu\""
@test sprint(show_compact, ulyanovsk) == "tz\"Europe/Ulyanovsk\""
@test sprint(show_compact, custom) == "VariableTimeZone(\"Test/Custom\", ...)"

@test sprint(show, utc) == "tz\"UTC\""
@test sprint(show, gmt) == "tz\"GMT\""
@test sprint(show, foo) == "FixedTimeZone(\"FOO\", 0)"
@test sprint(show, null) == "FixedTimeZone(\"\", 10800)"
@test sprint(show, fixed) == "tz\"UTC+01:00\""
@test sprint(show, est) == "tz\"EST\""
@test sprint(show, warsaw) == "tz\"Europe/Warsaw\""
@test sprint(show, apia) == "tz\"Pacific/Apia\""
@test sprint(show, honolulu) == "tz\"Pacific/Honolulu\""
@test sprint(show, ulyanovsk) == "tz\"Europe/Ulyanovsk\""
@test sprint(show, custom) == "VariableTimeZone(\"Test/Custom\", Transition[Transition($(repr(custom_dt)), tz\"UTC\")], nothing)"

@test sprint(show, MIME("text/plain"), utc) == "UTC"
@test sprint(show, MIME("text/plain"), gmt) == "GMT"
@test sprint(show, MIME("text/plain"), foo) == "FOO (UTC+0)"
@test sprint(show, MIME("text/plain"), null) == "UTC+03:00"
@test sprint(show, MIME("text/plain"), fixed) == "UTC+01:00"
@test sprint(show, MIME("text/plain"), est) == "EST (UTC-5)"
@test sprint(show, MIME("text/plain"), warsaw) == "Europe/Warsaw (UTC+1/UTC+2)"
@test sprint(show, MIME("text/plain"), apia) == "Pacific/Apia (UTC+13/UTC+14)"
@test sprint(show, MIME("text/plain"), honolulu) == "Pacific/Honolulu (UTC-10)"
@test sprint(show, MIME("text/plain"), ulyanovsk) == "Europe/Ulyanovsk (UTC+4)"
@test sprint(show, MIME("text/plain"), custom) == "Test/Custom (UTC+0)"

# ZonedDateTime as a string
zdt = ZonedDateTime(dt, warsaw)
@test string(zdt) == "1942-12-25T01:23:45+01:00"
@test sprint(show_compact, zdt) == "ZonedDateTime(1942, 12, 25, 1, 23, 45, tz\"Europe/Warsaw\")"
@test sprint(show, zdt) == "ZonedDateTime(1942, 12, 25, 1, 23, 45, tz\"Europe/Warsaw\")"
@test sprint(show, MIME("text/plain"), zdt) == "1942-12-25T01:23:45+01:00"

# Note: Test can be removed once `:compact_el` code is eliminated
zdt_vector = [zdt]
@test sprint(show, MIME("text/plain"), zdt_vector) == summary(zdt_vector) * ":\n 1942-12-25T01:23:45+01:00"

@test sprint(show, zdt_vector; context=:compact => true) == "ZonedDateTime{VariableTimeZone}[ZonedDateTime(1942, 12, 25, 1, 23, 45, tz\"Europe/Warsaw\")]"


# TimeZone parsing

# Make sure that TimeZone conversion specifiers are set (issue #24)
CONVERSION_SPECIFIERS = isdefined(Dates, :SLOT_RULE) ? Dates.keys(Dates.SLOT_RULE) : keys(Dates.CONVERSION_SPECIFIERS)
@test 'z' in CONVERSION_SPECIFIERS
@test 'Z' in CONVERSION_SPECIFIERS

df = Dates.DateFormat("z")
@test parse_components("+0100", df) == Any[FixedTimeZone("+01:00")]
@test_throws ArgumentError parse_components("EST", df)
@test_throws ArgumentError parse_components("UTC", df)
@test_throws ArgumentError parse_components("Europe/Warsaw", df)

df = Dates.DateFormat("Z")
@test_throws ArgumentError parse_components("+0100", df)
@test_throws ArgumentError parse_components("EST", df)
@test parse_components("UTC", df) == Any[FixedTimeZone("UTC")]
@test parse_components("Europe/Warsaw", df) == Any[warsaw]

# ZonedDateTime parsing.
# Note: uses compiled time zone information. If these tests are failing try to rebuild
# the TimeZones package.
@test ZonedDateTime("1942-12-25T01:23:45.000+01:00") == ZonedDateTime(dt, fixed)
@test ZonedDateTime("1942-12-25T01:23:45+0100", "yyyy-mm-ddTHH:MM:SSzzz") == ZonedDateTime(dt, fixed)
@test ZonedDateTime("1942-12-25T01:23:45 Europe/Warsaw", "yyyy-mm-ddTHH:MM:SS ZZZ") == ZonedDateTime(dt, warsaw)
@test ZonedDateTime("1942-12-25T01:23:45 America/New_York", "yyyy-mm-ddTHH:MM:SS ZZZ") == ZonedDateTime(dt, new_york)

x = "1942-12-25T01:23:45.123+01:00"
@test string(ZonedDateTime(x)) == x

# Note: CET here represents the FixedTimeZone used in Europe/Warsaw and not the
# VariableTimeZone CET.
@test_throws ArgumentError ZonedDateTime("1942-12-25T01:23:45 CET", "yyyy-mm-ddTHH:MM:SS ZZZ")

# Creating a ZonedDateTime requires a TimeZone to be present.
@test_throws ArgumentError ZonedDateTime("1942-12-25T01:23:45", "yyyy-mm-ddTHH:MM:SSzzz")


# ZonedDateTime formatting
f = "yyyy/m/d H:M:S ZZZ"
@test Dates.format(ZonedDateTime(dt, fixed), f) == "1942/12/25 1:23:45 UTC+01:00"
@test Dates.format(ZonedDateTime(dt, warsaw), f) == "1942/12/25 1:23:45 CET"
@test Dates.format(ZonedDateTime(dt, ulyanovsk), f) == "1942/12/25 1:23:45 UTC+04:00"

f = "yyyy/m/d H:M:S zzz"
@test Dates.format(ZonedDateTime(dt, fixed), f) == "1942/12/25 1:23:45 +01:00"
@test Dates.format(ZonedDateTime(dt, warsaw), f) == "1942/12/25 1:23:45 +01:00"
@test Dates.format(ZonedDateTime(dt, ulyanovsk), f) == "1942/12/25 1:23:45 +04:00"


# The "Z" slot displays the time zone abbreviation for VariableTimeZones. It is fine to use
# the abbreviation for display purposes but not fine for parsing. This means that we
# currently cannot parse all strings produced by format.
df = Dates.DateFormat("yyyy-mm-ddTHH:MM:SS ZZZ")
zdt = ZonedDateTime(dt, warsaw)
@test_throws ArgumentError parse(ZonedDateTime, Dates.format(zdt, df), df)


# Displaying VariableTimeZone's vector of transitions on the REPL has a special printing
@testset "Transitions I/O" begin
    transitions = honolulu.transitions  # Only contains a few transitions
    t = transitions[2]  # 1896-01-13T22:31:26 UTC-10:30/+0 (HST)

    @testset "basic" begin
        @test sprint(print, t) == "1896-01-13T22:31:26 UTC-10:30/+0 (HST)"
        @test sprint(show_compact, t) == "1896-01-13T22:31:26 UTC-10:30/+0 (HST)"
        @test sprint(show, t) == "Transition($(repr(t.utc_datetime)), FixedTimeZone(\"HST\", -37800))"
        @test sprint(show, MIME("text/plain"), t) == "1896-01-13T22:31:26 UTC-10:30/+0 (HST)"
    end

    @testset "REPL vector" begin
        expected_full = string(
            Transition,
            "[",
            join(map(t -> sprint(show, t, context=:compact => false), transitions), ", "),
            "]",
        )

        # Note: The output here is different from the interactive REPL but is representative
        # of the output.
        expected_repl = string(
            Transition,
            "[",
            join(map(t -> sprint(show, t, context=:compact => true), transitions), ", "),
            "]",
        )

        @test sprint(show, transitions, context=:compact => false) == expected_full
        @test sprint(show, transitions; context=:compact_el => true) == expected_repl
    end
end
