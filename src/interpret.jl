# Compare a local instant to a UTC transition instant by using the offset to make them both
# into local time. We could just as easily convert both of them into UTC time.
lt_local(local_dt::DateTime, t::Transition) = isless(local_dt, t.utc_datetime + t.zone.offset)
lt_local(t::Transition, local_dt::DateTime) = isless(t.utc_datetime + t.zone.offset, local_dt)

lt_utc(utc_dt::DateTime, t::Transition) = isless(utc_dt, t.utc_datetime)
lt_utc(t::Transition, utc_dt::DateTime) = isless(t.utc_datetime, utc_dt)

function transition_range(local_dt::DateTime, tz::VariableTimeZone, ::Type{Local})
    # To understand the logic in this function some background on transitions is needed:
    #
    # A transition (`t[i]`) is applicable to a given UTC instant that occurs on or after the
    # transition start (`t[i].utc_datetime`). The transition (`t[i]`) ends at the start of
    # the next transition in the list (`t[i + 1].utc_datetime`).
    #
    # Any UTC instant that occurs prior to the first transition (`t[1].utc_datetime`) has no
    # associated transitions. Any UTC instant that occurs on or after the last transition
    # (`t[end].utc_datetime`) is associated, at a minimum, with the last transition.

    # Determine the latest transition that applies to `local_dt`. If the `local_dt`
    # preceeds all transitions `finish` will be zero and produce the empty range `1:0`.
    finish = searchsortedlast(tz.transitions, local_dt, lt=lt_local)

    # Usually we'll begin by having `start` be larger than `finish` to create an empty
    # range by default. In the scenario where last transition applies to the `local_dt` we
    # can avoid a bounds by setting `start = finish`.
    len = length(tz.transitions)
    start = finish < len ? finish + 1 : len

    # To determine the first transition that applies to the `local_dt` we will work
    # backwards. Typically, this loop will only use single iteration as multiple iterations
    # only occur when local times are ambiguous.
    @inbounds for i in (start - 1):-1:1
        # Compute the end of the transition in local time. Note that this instant is not
        # included in the implicitly defined transition interval (known as right-open in
        # interval parlance).
        transition_end = tz.transitions[i + 1].utc_datetime + tz.transitions[i].zone.offset

        # If the end of the transition occurs after the `local_dt` then this transition
        # applies to the `local_dt`.
        if transition_end > local_dt
            start = i
        else
            break
        end
    end

    return start:finish
end

function transition_range(utc_dt::DateTime, tz::VariableTimeZone, ::Type{UTC})
    finish = searchsortedlast(tz.transitions, utc_dt, lt=lt_utc)
    start = max(finish, 1)
    return start:finish
end

"""
    transition_range(dt::DateTime, tz::VariableTimeZone, context::Type{Union{Local,UTC}}) -> UnitRange

Finds the indexes of the `tz` transitions which may be applicable for the `dt`. The given
DateTime is expected to be local to the time zone or in UTC as specified by `context`. Note
that UTC context will always return a range of length one.
"""
transition_range(::DateTime, ::VariableTimeZone, ::Type{Union{Local,UTC}})

function interpret(local_dt::DateTime, tz::VariableTimeZone, ::Type{Local})
    t = tz.transitions
    r = transition_range(local_dt, tz, Local)

    possible = (ZonedDateTime(local_dt - t[i].zone.offset, tz, t[i].zone) for i in r)
    return IndexableGenerator(possible)
end

function interpret(utc_dt::DateTime, tz::VariableTimeZone, ::Type{UTC})
    t = tz.transitions
    r = transition_range(utc_dt, tz, UTC)
    length(r) == 1 || error("Internal TimeZones error: A UTC DateTime should only have a single interpretation")

    possible = (ZonedDateTime(utc_dt, tz, t[i].zone) for i in r)
    return IndexableGenerator(possible)
end

"""
    interpret(dt::DateTime, tz::VariableTimeZone, context::Type{Union{Local,UTC}}) -> Array{ZonedDateTime}

Produces a list of possible `ZonedDateTime`s given a `DateTime` and `VariableTimeZone`.
The result will be returned in chronological order. Note that `DateTime`s in the local
context typically return 0-2 results while the UTC context will always return 1 result.
"""
interpret(::DateTime, ::VariableTimeZone, ::Type{Union{Local,UTC}})

"""
    shift_gap(local_dt::DateTime, tz::VariableTimeZone) -> Tuple

Given a non-existent local `DateTime` in a `TimeZone` produces a tuple containing two valid
`ZonedDateTime`s that span the gap. Providing a valid local `DateTime` returns an empty
tuple. Note that this function does not support passing in a UTC `DateTime` since there are
no non-existent UTC `DateTime`s.

Aside: the function name refers to a period of invalid local time (gap) caused by daylight
saving time or offset changes (shift).
"""
function shift_gap(local_dt::DateTime, tz::VariableTimeZone)
    r = transition_range(local_dt, tz, Local)
    boundaries = if isempty(r) && last(r) > 0
        t = tz.transitions
        i, j = last(r), first(r)  # Empty range has the indices we want but backwards
        tuple(
            ZonedDateTime(t[i + 1].utc_datetime - eps(local_dt), tz, t[i].zone),
            ZonedDateTime(t[j].utc_datetime, tz, t[j].zone),
        )
    else
        tuple()
    end

    return boundaries
end

"""
    first_valid(local_dt::DateTime, tz::VariableTimeZone, step::Period)

Construct a valid `ZonedDateTime` by adjusting the local `DateTime`. If the local `DateTime`
is non-existent then it will be adjusted using the `step` to be *after* the gap. When the
local `DateTime` is ambiguous the *first* ambiguous `DateTime` will be returned.
"""
function first_valid(local_dt::DateTime, tz::VariableTimeZone, step::Period)
    possible = interpret(local_dt, tz, Local)

    # Skip all non-existent local datetimes.
    while isempty(possible)
        local_dt += step
        possible = interpret(local_dt, tz, Local)
    end

    return first(possible)
end

"""
    last_valid(local_dt::DateTime, tz::VariableTimeZone, step::Period)

Construct a valid `ZonedDateTime` by adjusting the local `DateTime`. If the local `DateTime`
is non-existent then it will be adjusted using the `step` to be *before* the gap. When the
local `DateTime` is ambiguous the *last* ambiguous `DateTime` will be returned.
"""
function last_valid(local_dt::DateTime, tz::VariableTimeZone, step::Period)
    possible = interpret(local_dt, tz, Local)

    # Skip all non-existent local datetimes.
    while isempty(possible)
        local_dt -= step
        possible = interpret(local_dt, tz, Local)
    end

    return last(possible)
end

function first_valid(local_dt::DateTime, tz::VariableTimeZone)
    possible = interpret(local_dt, tz, Local)
    return isempty(possible) ? last(shift_gap(local_dt, tz)) : first(possible)
end

function last_valid(local_dt::DateTime, tz::VariableTimeZone)
    possible = interpret(local_dt, tz, Local)
    return isempty(possible) ? first(shift_gap(local_dt, tz)) : last(possible)
end


first_valid(dt::DateTime, tz::IANATimeZone, args...) = _do_and_rewrap(first_valid, dt, tz, args...)
last_valid(dt::DateTime, tz::IANATimeZone, args...) = _do_and_rewrap(last_valid, dt, tz, args...)
