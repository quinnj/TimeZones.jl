import Base.Broadcast: broadcasted

# ZonedDateTime arithmetic
Base.:(+)(x::ZonedDateTime) = x
Base.:(-)(x::ZonedDateTime, y::ZonedDateTime) = x.utc_datetime - y.utc_datetime

function Base.:(+)(zdt::ZonedDateTime, p::DatePeriod)
    return ZonedDateTime(DateTime(zdt) + p, timezone(zdt))
end
function Base.:(+)(zdt::ZonedDateTime, p::TimePeriod)
    return ZonedDateTime(DateTime(zdt, UTC) + p, timezone(zdt); from_utc=true)
end
function Base.:(-)(zdt::ZonedDateTime, p::DatePeriod)
    return ZonedDateTime(DateTime(zdt) - p, timezone(zdt))
end
function Base.:(-)(zdt::ZonedDateTime, p::TimePeriod)
    return ZonedDateTime(DateTime(zdt, UTC) - p, timezone(zdt); from_utc=true)
end

function broadcasted(::typeof(+), r::StepRange{<:ZonedDateTime}, p::DatePeriod)
    start, step, stop = first(r), Base.step(r), last(r)

    # Since the local time + period can result in an invalid local datetime when working with
    # VariableTimeZones we will use `first_valid` and `last_valid` which avoids issues with
    # non-existent and ambiguous dates.

    tz = timezone(start)
    if isa(tz, VariableTimeZone)
        start = first_valid(DateTime(start) + p, tz, step)
    else
        start = start + p
    end

    tz = timezone(stop)
    if isa(tz, VariableTimeZone)
        stop = last_valid(DateTime(stop) + p, tz, step)
    else
        stop = stop + p
    end

    return StepRange(start, step, stop)
end

function broadcasted(::typeof(+), r::StepRange{<:ZonedDateTime}, p::TimePeriod)
    return StepRange(r.start + p, r.step, r.stop + p)
end

broadcasted(::typeof(+), p::Period, r::StepRange{<:ZonedDateTime}) = broadcasted(+, r, p)
broadcasted(::typeof(-), r::StepRange{<:ZonedDateTime}, p::Period) = broadcasted(+, r, -p)
broadcasted(::typeof(-), p::Period, r::StepRange{<:ZonedDateTime}) = broadcasted(-, r, p)
