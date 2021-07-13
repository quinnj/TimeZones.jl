using Dates: unix2datetime, datetime2unix, julian2datetime, datetime2julian
using Mocking: Mocking, @mock

# UTC is an abstract type defined in Dates, for some reason
const utc_tz = FixedTimeZone("UTC")


"""
    DateTime(zdt::ZonedDateTime) -> DateTime

Create a `DateTime` by dropping the associated time zone. Effectively, this new `DateTime`
is implicitly associated with `timezone(zdt)`.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> DateTime(zdt)
2014-05-30T21:00:00
```
"""
Dates.DateTime(zdt::ZonedDateTime) = zdt.utc_datetime + zdt.zone.offset

"""
    DateTime(zdt::ZonedDateTime, ::Type{UTC}) -> DateTime

Create a `DateTime` which is implicitly associated with UTC.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> DateTime(zdt, UTC)
2014-05-31T01:00:00
```
"""
Dates.DateTime(zdt::ZonedDateTime, ::Type{UTC}) = zdt.utc_datetime


"""
    Date(zdt::ZonedDateTime) -> Date

Create a `Date` by dropping the associated time zone. Effectively, this new `Date`
is implicitly associated with `timezone(zdt)`.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> Date(zdt)
2014-05-30
```
"""
Dates.Date(zdt::ZonedDateTime) = Date(DateTime(zdt))


"""
    Date(zdt::ZonedDateTime, ::Type{UTC}) -> Date

Create a `Date` which is implicitly associated with UTC.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> Date(zdt, UTC)
2014-05-31
```
"""
Dates.Date(zdt::ZonedDateTime, ::Type{UTC}) = Date(DateTime(zdt, UTC))


"""
    Time(zdt::ZonedDateTime) -> Time

Create a `Time` by dropping the associated time zone. Effectively, this new `Time`
is implicitly associated with `timezone(zdt)`.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> Time(zdt)
21:00:00
```
"""
Dates.Time(zdt::ZonedDateTime) = Time(DateTime(zdt))


"""
    Time(zdt::ZonedDateTime, ::Type{UTC}) -> Date

Create a `Time` which is implicitly associated with UTC.

# Example

```jldoctest
julia> zdt = ZonedDateTime(2014, 5, 30, 21, tz"UTC-4")
2014-05-30T21:00:00-04:00

julia> Time(zdt, UTC)
01:00:00
```
"""
Dates.Time(zdt::ZonedDateTime, ::Type{UTC}) = Time(DateTime(zdt, UTC))


"""
    now(::TimeZone) -> ZonedDateTime

Returns a `ZonedDateTime` corresponding to the user's system time in the specified `TimeZone`.
"""
function Dates.now(tz::TimeZone)
    utc = unix2datetime(time())
    ZonedDateTime(utc, tz, from_utc=true)
end

"""
    today(tz::TimeZone) -> Date

Returns the date portion of `now(tz)` in local time.

# Examples

```julia
julia> a, b = now(tz"Pacific/Midway"), now(tz"Pacific/Apia")
(2017-11-09T03:47:04.226-11:00, 2017-11-10T04:47:04.226+14:00)

julia> a - b
0 milliseconds

julia> today(tz"Pacific/Midway"), today(tz"Pacific/Apia")
(2017-11-09, 2017-11-10)
```
"""
Dates.today(tz::TimeZone) = Date(now(tz))

"""
    todayat(tod::Time, tz::TimeZone, [amb]) -> ZonedDateTime

Creates a `ZonedDateTime` for today at the specified time of day. If the result is ambiguous
in the given `TimeZone` then `amb` can be supplied to resolve ambiguity.

# Examples

```julia
julia> today(tz"Europe/Warsaw")
2017-11-09

julia> todayat(Time(10, 30), tz"Europe/Warsaw")
2017-11-09T10:30:00+01:00
```
"""
function todayat(tod::Time, tz::VariableTimeZone, amb::Union{Integer,Bool})
    ZonedDateTime((@mock today(tz)) + tod, tz, amb)
end

todayat(tod::Time, tz::TimeZone) = ZonedDateTime((@mock today(tz)) + tod, tz)


"""
    astimezone(zdt::ZonedDateTime, tz::TimeZone) -> ZonedDateTime

Converts a `ZonedDateTime` from its current `TimeZone` into the specified `TimeZone`.
"""
function astimezone end

astimezone(zdt::ZonedDateTime, tz::IANATimeZone) = _do_and_rewrap(astimezone, zdt, tz)

function astimezone(zdt::ZonedDateTime, tz::VariableTimeZone)
    i = searchsortedlast(
        tz.transitions, zdt.utc_datetime,
        by=v -> typeof(v) == Transition ? v.utc_datetime : v,
    )

    if i == 0
        throw(NonExistentTimeError(DateTime(zdt), tz))
    end

    zone = tz.transitions[i].zone
    return ZonedDateTime(zdt.utc_datetime, tz, zone)
end

function astimezone(zdt::ZonedDateTime, tz::FixedTimeZone)
    return ZonedDateTime(zdt.utc_datetime, tz, tz)
end

function zdt2julian(zdt::ZonedDateTime)
    datetime2julian(DateTime(zdt, UTC))
end

function zdt2julian(::Type{T}, zdt::ZonedDateTime) where T<:Integer
    floor(T, datetime2julian(DateTime(zdt, UTC)))
end

function zdt2julian(::Type{T}, zdt::ZonedDateTime) where T<:Real
    convert(T, datetime2julian(DateTime(zdt, UTC)))
end

function julian2zdt(jd::Real)
    ZonedDateTime(julian2datetime(jd), utc_tz, from_utc=true)
end

function zdt2unix(zdt::ZonedDateTime)
    datetime2unix(DateTime(zdt, UTC))
end

function zdt2unix(::Type{T}, zdt::ZonedDateTime) where T<:Integer
    floor(T, datetime2unix(DateTime(zdt, UTC)))
end

function zdt2unix(::Type{T}, zdt::ZonedDateTime) where T<:Real
    convert(T, datetime2unix(DateTime(zdt, UTC)))
end

function unix2zdt(seconds::Real)
    ZonedDateTime(unix2datetime(seconds), utc_tz, from_utc=true)
end
