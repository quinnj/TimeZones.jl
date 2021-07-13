using Dates: AbstractDateTime, argerror, validargs

# """
#     ZonedDateTime

# A `DateTime` that includes `TimeZone` information.
# """

struct ZonedDateTime <: AbstractDateTime
    utc_datetime::DateTime
    timezone::TimeZone
    zone::FixedTimeZone  # The current zone for the utc_datetime.

    function ZonedDateTime(utc_datetime::DateTime, timezone::TimeZone, zone::FixedTimeZone)
        return new(utc_datetime, timezone, zone)
    end

    function ZonedDateTime(utc_datetime::DateTime, timezone::VariableTimeZone, zone::FixedTimeZone)
        if timezone.cutoff !== nothing && utc_datetime >= timezone.cutoff
            throw(UnhandledTimeError(timezone))
        end

        return new(utc_datetime, timezone, zone)
    end
end

"""
    ZonedDateTime(dt::DateTime, tz::TimeZone; from_utc=false) -> ZonedDateTime

Construct a `ZonedDateTime` by applying a `TimeZone` to a `DateTime`. When the `from_utc`
keyword is true the given `DateTime` is assumed to be in UTC instead of in local time and is
converted to the specified `TimeZone`.  Note that when `from_utc` is true the given
`DateTime` will always exists and is never ambiguous.
"""
function ZonedDateTime(dt::DateTime, tz::VariableTimeZone; from_utc::Bool=false)
    # Note: Using a function barrier which reduces allocations
    function construct(T::Type{<:Union{Local,UTC}})
        possible = interpret(dt, tz, T)

        num = length(possible)
        if num == 1
            return first(possible)
        elseif num == 0
            throw(NonExistentTimeError(dt, tz))
        else
            throw(AmbiguousTimeError(dt, tz))
        end
    end

    return construct(from_utc ? UTC : Local)
end

function ZonedDateTime(dt::DateTime, tz::FixedTimeZone; from_utc::Bool=false)
    utc_dt = from_utc ? dt : dt - tz.offset
    return ZonedDateTime(utc_dt, tz, tz)
end

"""
    ZonedDateTime(dt::DateTime, tz::VariableTimeZone, occurrence::Integer) -> ZonedDateTime

Construct a `ZonedDateTime` by applying a `TimeZone` to a `DateTime`. If the `DateTime` is
ambiguous within the given time zone you can set `occurrence` to a positive integer to
resolve the ambiguity.
"""
function ZonedDateTime(dt::DateTime, tz::VariableTimeZone, occurrence::Integer)
    possible = interpret(dt, tz, Local)

    num = length(possible)
    if num == 1
        return first(possible)
    elseif num == 0
        throw(NonExistentTimeError(dt, tz))
    elseif occurrence > 0
        return possible[occurrence]
    else
        throw(AmbiguousTimeError(dt, tz))
    end
end

"""
    ZonedDateTime(dt::DateTime, tz::VariableTimeZone, is_dst::Bool) -> ZonedDateTime

Construct a `ZonedDateTime` by applying a `TimeZone` to a `DateTime`. If the `DateTime` is
ambiguous within the given time zone you can set `is_dst` to resolve the ambiguity.
"""
function ZonedDateTime(dt::DateTime, tz::VariableTimeZone, is_dst::Bool)
    possible = interpret(dt, tz, Local)

    num = length(possible)
    if num == 1
        return first(possible)
    elseif num == 0
        throw(NonExistentTimeError(dt, tz))
    elseif num == 2
        mask = [isdst(zdt.zone.offset) for zdt in possible]

        # Mask is expected to be unambiguous.
        !xor(mask...) && throw(AmbiguousTimeError(dt, tz))

        occurrence = findfirst(d -> d == is_dst, mask)
        return possible[occurrence]
    else
        throw(AmbiguousTimeError(dt, tz))
    end
end

function ZonedDateTime(dt::DateTime, tz::IANATimeZone, occ_or_dst::Integer)
    return _do_and_rewrap(ZonedDateTime, dt, tz, occ_or_dst)
end

function ZonedDateTime(dt::DateTime, tz::IANATimeZone; kwargs...)
    return _do_and_rewrap(ZonedDateTime, dt, tz; kwargs...)
end

# Convenience constructors
@doc """
    ZonedDateTime(y, [m, d, h, mi, s, ms], tz, [amb]) -> DateTime

Construct a `ZonedDateTime` type by parts. Arguments `y, m, ..., ms` must be convertible to
`Int64` and `tz` must be a `TimeZone`. If the given `DateTime` is ambiguous in the given
`TimeZone` then `amb` can be supplied to resolve ambiguity.
""" ZonedDateTime

@optional function ZonedDateTime(y::Integer, m::Integer=1, d::Integer=1, h::Integer=0, mi::Integer=0, s::Integer=0, ms::Integer=0, tz::AbstractVariableTimeZone, amb::Union{Integer,Bool})
    ZonedDateTime(DateTime(y,m,d,h,mi,s,ms), tz, amb)
end

@optional function ZonedDateTime(y::Integer, m::Integer=1, d::Integer=1, h::Integer=0, mi::Integer=0, s::Integer=0, ms::Integer=0, tz::TimeZone)
    ZonedDateTime(DateTime(y,m,d,h,mi,s,ms), tz)
end

# Parsing constructor needed as part of the Dates parsing interface. Note we typically don't
# support passing in time zone information as a string since we cannot do not know if we
# need to support resolving ambiguity.
#
# Since we do not want users accidentially calling this function we'll use very specific
# type assertions:
# https://github.com/JuliaTime/TimeZones.jl/issues/187#issuecomment-473012078
function ZonedDateTime(y::Int64, m::Union{Int32, Int64}, d::Int64, h::Int64, mi::Int64, s::Int64, ms::Int64, tz::AbstractString)
    ZonedDateTime(DateTime(y,m,d,h,mi,s,ms), TimeZone(tz))
end


function ZonedDateTime(parts::Union{Period,TimeZone}...)
    periods = Period[]
    tz = nothing
    for part in parts
        if isa(part, Period)
            push!(periods, part)
        elseif tz === nothing
            tz = part
        else
            throw(ArgumentError("Multiple time zones found"))
        end
    end

    tz === nothing && throw(ArgumentError("Missing time zone"))
    return ZonedDateTime(DateTime(periods...), tz)
end

function ZonedDateTime(date::Date, args...; kwargs...)
    return ZonedDateTime(DateTime(date), args...; kwargs...)
end

# Promotion

# Because of the promoting fallback definitions for TimeType, we need a special case for
# undefined promote_rule on TimeType types.
# Otherwise, typejoin(T,S) is called (returning TimeType) so no conversion happens, and
# isless(promote(x,y)...) is called again, causing a stack overflow.
function Base.promote_rule(::Type{T}, ::Type{S}) where {T<:TimeType, S<:ZonedDateTime}
    error("no promotion exists for ", T, " and ", S)
end

# Equality
Base.:(==)(a::ZonedDateTime, b::ZonedDateTime) = a.utc_datetime == b.utc_datetime
Base.isless(a::ZonedDateTime, b::ZonedDateTime) = isless(a.utc_datetime, b.utc_datetime)
Base.isequal(a::ZonedDateTime, b::ZonedDateTime) = isequal(a.utc_datetime, b.utc_datetime)

"""
    hash(::ZonedDateTime, h)

Compute an integer hash code for a ZonedDateTime by hashing the `utc_datetime` field.
`hash(:utc_instant, h)` is used to avoid collisions with `DateTime` hashes.
"""
function Base.hash(zdt::ZonedDateTime, h::UInt)
    h = hash(:utc_instant, h)
    h = hash(zdt.utc_datetime, h)
    return h
end

Base.typemin(::Type{ZonedDateTime}) = ZonedDateTime(typemin(DateTime), utc_tz; from_utc=true)
Base.typemax(::Type{ZonedDateTime}) = ZonedDateTime(typemax(DateTime), utc_tz; from_utc=true)

# Note: The `validargs` function is as part of the Dates parsing interface.
function Dates.validargs(::Type{ZonedDateTime}, y::Int64, m::Union{Int64, Int32}, d::Int64, h::Int64, mi::Int64, s::Int64, ms::Int64, tz::AbstractString)
    err = validargs(DateTime, y, Int64(m), d, h, mi, s, ms)
    err === nothing || return err
    istimezone(tz) || return argerror("TimeZone: \"$tz\" is not a recognized time zone")
    return argerror()
end
