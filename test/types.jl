import TimeZones: Transition
import Compat.Dates: Hour, Second, UTM


# Constructor FixedTimeZone from a string.
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


# Test exception messages
tz = VariableTimeZone(
    "Imaginary/Zone",
    [Transition(DateTime(1800,1,1), FixedTimeZone("IST",0,0))],
    DateTime(1980,1,1),
)

@test sprint(showerror, AmbiguousTimeError(DateTime(2015,1,1), tz)) ==
    "AmbiguousTimeError: Local DateTime 2015-01-01T00:00:00 is ambiguous within Imaginary/Zone"
@test sprint(showerror, NonExistentTimeError(DateTime(2015,1,1), tz)) ==
    "NonExistentTimeError: Local DateTime 2015-01-01T00:00:00 does not exist within Imaginary/Zone"
@test sprint(showerror, UnhandledTimeError(tz)) ==
    "UnhandledTimeError: TimeZone Imaginary/Zone does not handle dates on or after 1980-01-01T00:00:00 UTC"


warsaw = resolve("Europe/Warsaw", tzdata["europe"]...)

# Standard time behaviour
local_dt = DateTime(1916, 2, 1, 0)
utc_dt = DateTime(1916, 1, 31, 23)

# Disambiguating parameters ignored when there is no ambiguity.
@test Localized(local_dt, warsaw).zone.name == :CET
@test Localized(local_dt, warsaw, 1).zone.name == :CET
@test Localized(local_dt, warsaw, 2).zone.name == :CET
@test Localized(local_dt, warsaw, true).zone.name == :CET
@test Localized(local_dt, warsaw, false).zone.name == :CET
@test Localized(utc_dt, warsaw, from_utc=true).zone.name == :CET

@test Localized(local_dt, warsaw).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, 1).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, 2).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, true).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, false).utc_datetime == utc_dt
@test Localized(utc_dt, warsaw, from_utc=true).utc_datetime == utc_dt


# Daylight saving time behaviour
local_dt = DateTime(1916, 6, 1, 0)
utc_dt = DateTime(1916, 5, 31, 22)

# Disambiguating parameters ignored when there is no ambiguity.
@test Localized(local_dt, warsaw).zone.name == :CEST
@test Localized(local_dt, warsaw, 1).zone.name == :CEST
@test Localized(local_dt, warsaw, 2).zone.name == :CEST
@test Localized(local_dt, warsaw, true).zone.name == :CEST
@test Localized(local_dt, warsaw, false).zone.name == :CEST
@test Localized(utc_dt, warsaw, from_utc=true).zone.name == :CEST

@test Localized(local_dt, warsaw).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, 1).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, 2).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, true).utc_datetime == utc_dt
@test Localized(local_dt, warsaw, false).utc_datetime == utc_dt
@test Localized(utc_dt, warsaw, from_utc=true).utc_datetime == utc_dt


# Typical "spring-forward" behaviour
local_dts = (
    DateTime(1916,4,30,22),
    DateTime(1916,4,30,23),
    DateTime(1916,5,1,0),
)
utc_dts = (
    DateTime(1916,4,30,21),
    DateTime(1916,4,30,22),
)
@test_throws NonExistentTimeError Localized(local_dts[2], warsaw)
@test_throws NonExistentTimeError Localized(local_dts[2], warsaw, 1)
@test_throws NonExistentTimeError Localized(local_dts[2], warsaw, 2)
@test_throws NonExistentTimeError Localized(local_dts[2], warsaw, true)
@test_throws NonExistentTimeError Localized(local_dts[2], warsaw, false)

@test Localized(local_dts[1], warsaw).zone.name == :CET
@test Localized(local_dts[3], warsaw).zone.name == :CEST
@test Localized(utc_dts[1], warsaw, from_utc=true).zone.name == :CET
@test Localized(utc_dts[2], warsaw, from_utc=true).zone.name == :CEST

@test Localized(local_dts[1], warsaw).utc_datetime == utc_dts[1]
@test Localized(local_dts[3], warsaw).utc_datetime == utc_dts[2]
@test Localized(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
@test Localized(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]


# Typical "fall-back" behaviour
local_dt = DateTime(1916, 10, 1, 0)
utc_dts = (DateTime(1916, 9, 30, 22), DateTime(1916, 9, 30, 23))
@test_throws AmbiguousTimeError Localized(local_dt, warsaw)

@test Localized(local_dt, warsaw, 1).zone.name == :CEST
@test Localized(local_dt, warsaw, 2).zone.name == :CET
@test Localized(local_dt, warsaw, true).zone.name == :CEST
@test Localized(local_dt, warsaw, false).zone.name == :CET
@test Localized(utc_dts[1], warsaw, from_utc=true).zone.name == :CEST
@test Localized(utc_dts[2], warsaw, from_utc=true).zone.name == :CET

@test Localized(local_dt, warsaw, 1).utc_datetime == utc_dts[1]
@test Localized(local_dt, warsaw, 2).utc_datetime == utc_dts[2]
@test Localized(local_dt, warsaw, true).utc_datetime == utc_dts[1]
@test Localized(local_dt, warsaw, false).utc_datetime == utc_dts[2]
@test Localized(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
@test Localized(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]

# Zone offset reduced creating an ambiguous hour
local_dt = DateTime(1922,5,31,23)
utc_dts = (DateTime(1922, 5, 31, 21), DateTime(1922, 5, 31, 22))
@test_throws AmbiguousTimeError Localized(local_dt, warsaw)

@test Localized(local_dt, warsaw, 1).zone.name == :EET
@test Localized(local_dt, warsaw, 2).zone.name == :CET
@test_throws AmbiguousTimeError Localized(local_dt, warsaw, true)
@test_throws AmbiguousTimeError Localized(local_dt, warsaw, false)
@test Localized(utc_dts[1], warsaw, from_utc=true).zone.name == :EET
@test Localized(utc_dts[2], warsaw, from_utc=true).zone.name == :CET

@test Localized(local_dt, warsaw, 1).utc_datetime == utc_dts[1]
@test Localized(local_dt, warsaw, 2).utc_datetime == utc_dts[2]
@test Localized(utc_dts[1], warsaw, from_utc=true).utc_datetime == utc_dts[1]
@test Localized(utc_dts[2], warsaw, from_utc=true).utc_datetime == utc_dts[2]


# Check behaviour when save is larger than an hour.
paris = resolve("Europe/Paris", tzdata["europe"]...)

@test Localized(DateTime(1945,4,2,1), paris).zone == FixedTimeZone("WEST", 0, 3600)
@test_throws NonExistentTimeError Localized(DateTime(1945,4,2,2), paris)
@test Localized(DateTime(1945,4,2,3), paris).zone == FixedTimeZone("WEMT", 0, 7200)

@test_throws AmbiguousTimeError Localized(DateTime(1945,9,16,2), paris)
@test Localized(DateTime(1945,9,16,2), paris, 1).zone == FixedTimeZone("WEMT", 0, 7200)
@test Localized(DateTime(1945,9,16,2), paris, 2).zone == FixedTimeZone("CET", 3600, 0)

# Ensure that dates are continuous when both a UTC offset and the DST offset change.
@test Localized(DateTime(1945,9,16,1), paris).utc_datetime == DateTime(1945,9,15,23)
@test Localized(DateTime(1945,9,16,2), paris, 1).utc_datetime == DateTime(1945,9,16,0)
@test Localized(DateTime(1945,9,16,2), paris, 2).utc_datetime == DateTime(1945,9,16,1)
@test Localized(DateTime(1945,9,16,3), paris).utc_datetime == DateTime(1945,9,16,2)


# Transitions changes that exceed an hour.
t = VariableTimeZone("Testing", [
    Transition(DateTime(1800,1,1), FixedTimeZone("TST",0,0)),
    Transition(DateTime(1950,4,1), FixedTimeZone("TDT",0,7200)),
    Transition(DateTime(1950,9,1), FixedTimeZone("TST",0,0)),
])

# A "spring forward" where 2 hours are skipped.
@test Localized(DateTime(1950,3,31,23), t).zone == FixedTimeZone("TST",0,0)
@test_throws NonExistentTimeError Localized(DateTime(1950,4,1,0), t)
@test_throws NonExistentTimeError Localized(DateTime(1950,4,1,1), t)
@test Localized(DateTime(1950,4,1,2), t).zone == FixedTimeZone("TDT",0,7200)


# A "fall back" where 2 hours are duplicated. Never appears to occur in reality.
@test Localized(DateTime(1950,8,31,23), t).utc_datetime == DateTime(1950,8,31,21)  # TDT

# First occurrences of duplicated hours.
@test Localized(DateTime(1950,9,1,0), t, 1).utc_datetime == DateTime(1950,8,31,22) # TST
@test Localized(DateTime(1950,9,1,1), t, 1).utc_datetime == DateTime(1950,8,31,23) # TST

# Second occurrences of duplicated hours.
@test Localized(DateTime(1950,9,1,0), t, 2).utc_datetime == DateTime(1950,9,1,0)   # TDT
@test Localized(DateTime(1950,9,1,1), t, 2).utc_datetime == DateTime(1950,9,1,1)   # TDT

@test Localized(DateTime(1950,9,1,2), t).utc_datetime == DateTime(1950,9,1,2)      # TDT


# Ambiguous local DateTime that has more than 2 solutions. Never occurs in reality.
t = VariableTimeZone("Testing", [
    Transition(DateTime(1800,1,1), FixedTimeZone("TST",0,0)),
    Transition(DateTime(1960,4,1), FixedTimeZone("TDT",0,7200)),
    Transition(DateTime(1960,8,31,23), FixedTimeZone("TXT",0,3600)),
    Transition(DateTime(1960,9,1), FixedTimeZone("TST",0,0)),
])

@test Localized(DateTime(1960,8,31,23), t).utc_datetime == DateTime(1960,8,31,21)  # TDT
@test Localized(DateTime(1960,9,1,0), t, 1).utc_datetime == DateTime(1960,8,31,22) # TDT
@test Localized(DateTime(1960,9,1,0), t, 2).utc_datetime == DateTime(1960,8,31,23) # TXT
@test Localized(DateTime(1960,9,1,0), t, 3).utc_datetime == DateTime(1960,9,1,0)   # TST
@test Localized(DateTime(1960,9,1,1), t).utc_datetime == DateTime(1960,9,1,1)      # TST

@test_throws AmbiguousTimeError Localized(DateTime(1960,9,1,0), t, true)
@test_throws AmbiguousTimeError Localized(DateTime(1960,9,1,0), t, false)


# Significant offset change: -11:00 -> 13:00.
apia = resolve("Pacific/Apia", tzdata["australasia"]...)

# Skips an entire day.
@test Localized(DateTime(2011,12,29,23),apia).utc_datetime == DateTime(2011,12,30,9)
@test_throws NonExistentTimeError Localized(DateTime(2011,12,30,0),apia)
@test_throws NonExistentTimeError Localized(DateTime(2011,12,30,23),apia)
@test Localized(DateTime(2011,12,31,0),apia).utc_datetime == DateTime(2011,12,30,10)


# Redundant transitions should be ignored.
# Note: that this can occur in reality if the TZ database parse has a Zone that ends at
# the same time a Rule starts. When this occurs the duplicates always in standard time
# with the same abbreviation.
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
@test_throws AmbiguousTimeError Localized(DateTime(1935,9,1), dup)
@test Localized(DateTime(1935,9,1), dup, 1).zone.name == Symbol("DTDT-2")
@test Localized(DateTime(1935,9,1), dup, 2).zone.name == :DTST
@test_throws BoundsError Localized(DateTime(1935,9,1), dup, 3)

# Ensure that DTDT-1 is completely ignored.
@test_throws NonExistentTimeError Localized(DateTime(1935,4,1), dup)
@test Localized(DateTime(1935,4,1,1), dup).zone.name == Symbol("DTDT-2")
@test Localized(DateTime(1935,8,31,23), dup).zone.name == Symbol("DTDT-2")


# Check equality between ZonedDateTimes
utc = FixedTimeZone("UTC", 0, 0)

spring_utc = Localized(DateTime(2010, 5, 1, 12), utc)
spring_apia = Localized(DateTime(2010, 5, 1, 1), apia)

# The absolutely min DateTime you can create. Even smaller than typemin(DateTime)
early_utc = Localized(DateTime(UTM(typemin(Int64))), utc)

@test spring_utc.zone == FixedTimeZone("UTC", 0, 0)
@test spring_apia.zone == FixedTimeZone("SST", -39600, 0)
@test spring_utc == spring_apia
@test spring_utc !== spring_apia
@test !isequal(spring_utc, spring_apia)
@test hash(spring_utc) != hash(spring_apia)
@test astimezone(spring_utc, apia) === spring_apia  # Since Localized is immutable
@test astimezone(spring_apia, utc) === spring_utc
@test isequal(astimezone(spring_utc, apia), spring_apia)
@test hash(astimezone(spring_utc, apia)) == hash(spring_apia)

fall_utc = Localized(DateTime(2010, 10, 1, 12), utc)
fall_apia = Localized(DateTime(2010, 10, 1, 2), apia)

@test fall_utc.zone == FixedTimeZone("UTC", 0, 0)
@test fall_apia.zone == FixedTimeZone("SDT", -39600, 3600)
@test fall_utc == fall_apia
@test fall_utc !== fall_apia
@test !(fall_utc < fall_apia)
@test !(fall_utc > fall_apia)
@test !isequal(fall_utc, fall_apia)
@test hash(fall_utc) != hash(fall_apia)
@test astimezone(fall_utc, apia) === fall_apia  # Since Localized is immutable
@test astimezone(fall_apia, utc) === fall_utc
@test isequal(astimezone(fall_utc, apia), fall_apia)
@test hash(astimezone(fall_utc, apia)) == hash(fall_apia)

# Issue #78
x = Localized(2017, 7, 6, 15, 44, 55, 28, warsaw)
y = deepcopy(x)

@test x == y
@test x !== y
@test !(x < y)
@test !(x > y)
@test isequal(x, y)
@test hash(x) == hash(y)


# A FixedTimeZone is effective for all of time where as a VariableTimeZone has as start.
@test TimeZones.utc(early_utc) < apia.transitions[1].utc_datetime
@test_throws NonExistentTimeError astimezone(early_utc, apia)


# Localized constructor that takes any number of Period or TimeZone types
@test_throws ArgumentError Localized(FixedTimeZone("UTC", 0, 0), FixedTimeZone("TMW", 86400, 0))


# Equality for VariableTimeZones
another_warsaw = resolve("Europe/Warsaw", tzdata["europe"]...)

@test warsaw == warsaw
@test warsaw === warsaw
@test warsaw == another_warsaw
@test warsaw !== another_warsaw
@test isequal(warsaw, another_warsaw)
@test hash(warsaw) == hash(another_warsaw)


# VariableTimeZone with a cutoff set
cutoff_tz = VariableTimeZone(
    "cutoff", [Transition(DateTime(1970, 1, 1), utc)], DateTime(1988, 5, 6),
)

Localized(DateTime(1970, 1, 1), cutoff_tz)  # pre cutoff
@test_throws UnhandledTimeError Localized(DateTime(1988, 5, 6), cutoff_tz)  # on cutoff
@test_throws UnhandledTimeError Localized(DateTime(1989, 5, 7), cutoff_tz)
@test_throws UnhandledTimeError Localized(DateTime(1988, 5, 5), cutoff_tz) + Hour(24)

ldt = Localized(DateTime(2038, 3, 28), warsaw, from_utc=true)
@test_throws UnhandledTimeError ldt + Hour(1)

# TimeZones that no longer have any transitions after the max_year shouldn't have a cutoff
# eg. Asia/Hong_Kong, Pacific/Honolulu, Australia/Perth
perth = resolve("Australia/Perth", tzdata["australasia"]...)
ldt = Localized(DateTime(2200, 1, 1), perth, from_utc=true)


# Convenience constructors for making a DateTime on-the-fly
digits = [2010, 1, 2, 3, 4, 5, 6]
for i in eachindex(digits)
    @test Localized(digits[1:i]..., warsaw) == Localized(DateTime(digits[1:i]...), warsaw)
    @test Localized(digits[1:i]..., utc) == Localized(DateTime(digits[1:i]...), utc)
end

# Convenience constructor dealing with ambiguous time
digits = [1916, 10, 1, 0, 2, 3, 4]  # Fall DST transition in Europe/Warsaw
for i in eachindex(digits)
    expected = [
        Localized(DateTime(digits[1:i]...), warsaw, 1)
        Localized(DateTime(digits[1:i]...), warsaw, 2)
    ]

    if i > 1
        @test_throws AmbiguousTimeError Localized(digits[1:i]..., warsaw)
    end

    @test Localized(digits[1:i]..., warsaw, 1) == expected[1]
    @test Localized(digits[1:i]..., warsaw, 2) == expected[2]
    @test Localized(digits[1:i]..., warsaw, true) == expected[1]
    @test Localized(digits[1:i]..., warsaw, false) == expected[2]
end

# Promotion
@test_throws ErrorException promote_type(Localized, Date)
@test_throws ErrorException promote_type(Localized, DateTime)
@test_throws ErrorException promote_type(Date, Localized)
@test_throws ErrorException promote_type(DateTime, Localized)
@test promote_type(Localized, Localized) == Localized

# Issue #52
dt = now()
@test_throws ErrorException Localized(dt, warsaw) > dt

# type extrema
@test typemin(Localized) <= Localized(typemin(DateTime), utc)
@test typemax(Localized) >= Localized(typemax(DateTime), utc)
