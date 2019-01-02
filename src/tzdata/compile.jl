using Dates
using Serialization
using Dates: parse_components

using ...TimeZones: TIME_ZONES
using ...TimeZones: TimeZones, TimeZone, FixedTimeZone, VariableTimeZone, Transition, rename
using ..TZData: TimeOffset, ZERO, MIN_GMT_OFFSET, MAX_GMT_OFFSET, MIN_SAVE, MAX_SAVE,
    ABS_DIFF_OFFSET

# Zone type maps to an Olson Timezone database entity
struct Zone
    gmtoffset::TimeOffset
    save::TimeOffset
    rules::Union{String,Nothing}
    format::AbstractString
    until::Union{DateTime,Nothing}
    until_flag::Char
end

function Base.isless(x::Zone, y::Zone)
    x_dt = something(x.until, typemax(DateTime))
    y_dt = something(y.until, typemax(DateTime))

    # Easy to compare until's if they are using the same flag. Alternatively, it should
    # be safe to compare different until flags if the DateTimes are far enough apart.
    if x.until_flag == y.until_flag || abs(x_dt - y_dt) > ABS_DIFF_OFFSET
        return isless(x_dt, y_dt)
    else
        error("Unable to compare zones when until datetimes are too close and flags are mixed")
    end
end

# Rules govern how Daylight Savings transitions happen for a given time zone
struct Rule
    from::Union{Int,Nothing}  # First year rule applies
    to::Union{Int,Nothing}    # Rule applies up until, but not including this year
    month::Int                # Month in which DST transition happens
    on::Function              # Anonymous boolean function to determine day
    at::TimeOffset            # Hour and minute at which the transition happens
    at_flag::Char             # Local wall time (w), UTC time (u), Local Standard time (s)
    save::TimeOffset          # How much time is "saved" in daylight savings transition
    letter::AbstractString    # Timezone abbr letter(s). ie. CKT ("") => CKHST ("HS")

    function Rule(from, to, month, on, at, at_flag, save, letter)
        isflag(at_flag) || throw(ArgumentError("Unhandled flag '$at_flag'"))
        new(from, to, month, on, at, at_flag, save, letter)
    end
end

struct TZSource
    zones::Dict{String,Vector{Zone}}
    rules::Dict{String,Vector{Rule}}
    links::Dict{String,String}
end

function TZSource()
    TZSource(
        Dict{String,Vector{Zone}}(),
        Dict{String,Vector{Rule}}(),
        Dict{String,String}(),
    )
end

TZSource(file::AbstractString) = load!(TZSource(), file)

function TZSource(files)
    tz_source = TZSource()

    for file in files
        load!(tz_source, file)
    end

    return tz_source
end

const OrderedRuleDict = Dict{String, Tuple{Vector{Date}, Vector{Rule}}}

# Min and max years that we create DST transition DateTimes for (inclusive)
const MIN_YEAR = year(typemin(DateTime))  # Essentially the begining of time
const MAX_YEAR = 2037                     # year(unix2datetime(typemax(Int32))) - 1

const DEFAULT_FLAG = 'w'

# Helper functions/data
const MONTHS = Dict(
    "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6,
    "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12,
)

const DAYS = Dict(
    "Mon" => 1, "Tue" => 2, "Wed" => 3, "Thu" => 4, "Fri" => 5, "Sat" => 6, "Sun" => 7,
)

const LAST_DAY_OF_WEEK = Dict{String, Function}()

# Create adjuster functions such as `last_sunday`.
for (abbr, dayofweek) in DAYS
    str = "last" * abbr
    f = Symbol("last_" * lowercase(dayname(dayofweek)))
    LAST_DAY_OF_WEEK[str] = @eval begin
        function $f(dt)
            return dayofweek(dt) == $dayofweek &&
            dayofweekofmonth(dt) == daysofweekinmonth(dt)
        end
    end
end

# Generate various DateFormats based the number of periods provided.
const UNTIL_FORMATS = let
    parts = split("yyyy uuu dd HH:MM:SS", ' ')
    map(i -> DateFormat(join(parts[1:i], ' ')), eachindex(parts))
end


isflag(flag::Char) = flag in ('w', 'u', 's')

"""
    tryparse_dayofmonth(str::AbstractString) -> Union{Function,Nothing}

Parse the various day-of-month formats used within tzdata source files.

```julia
julia> tryparse_dayofmonth("lastSun")
last_sunday (generic function with 1 method)

julia> tryparse_dayofmonth("Sun>=8")
#15 (generic function with 1 method)

julia> TimeZones.TZData.tryparse_dayofmonth("15")
#16 (generic function with 1 method)
```
"""
function tryparse_dayofmonth(str::AbstractString)
    if occursin(r"^last\w{3}$", str)
        # We pre-built these functions above
        # They follow the format: "lastSun", "lastMon", etc.
        LAST_DAY_OF_WEEK[str]
    elseif (m = match(r"^(?<dow>\w{3})(?<op>[<>]=)(?<dom>\d{1,2})$", str)) !== nothing
        # The first day of the week that occurs before or after a given day of month.
        # i.e. Sun>=8 refers to the Sunday after the 8th of the month
        # or in other words, the 2nd Sunday.
        dow = DAYS[m[:dow]]
        dom = parse(Int, m[:dom])
        if m[:op] == "<="
            dt -> day(dt) <= dom && dayofweek(dt) == dow
        else
            dt -> day(dt) >= dom && dayofweek(dt) == dow
        end
    elseif occursin(r"^\d{1,2}$", str)
        # Matches just a plain old day of the month
        dom = parse(Int, str)
        dt -> day(dt) == dom
    else
        nothing
    end
end

# Olson time zone dates can be a single year (1900), yyyy-mm-dd (1900-Jan-01),
# or minute-precision (1900-Jan-01 2:00).
# They can also be given in Local Wall Time, UTC time (u), or Local Standard time (s)
function parse_date(s::AbstractString)
    period_strs = split(s, r"\s+")
    num_periods = length(period_strs)

    # Extract the flag when time is included
    if num_periods > 3 && isflag(s[end])
        flag = s[end]
        period_strs[end] = period_strs[end][1:end - 1]
    else
        flag = DEFAULT_FLAG
    end

    # Save the day of month string and substitute a non-numeric string for parsing.
    dom_str = num_periods >= 3 ? period_strs[3] : ""
    numeric_dom = all(isnumeric, dom_str)
    !numeric_dom && splice!(period_strs, 3, ["1"])

    periods = parse_components(join(period_strs, ' '), UNTIL_FORMATS[num_periods])

    # Roll over 24:00 to the next day which occurs in "Pacific/Apia" and "Asia/Macau".
    # Note: Apply the `shift` after we create the DateTime to ensure that roll over works
    # correctly at the end of the month or year.
    shift = Day(0)
    if num_periods > 3 && periods[4] == Hour(24)
        periods[4] = Hour(0)
        shift += Day(1)
    end
    dt = DateTime(periods...)

    # Adjust the DateTime to reflect the requirements of the day-of-month function.
    if !numeric_dom
        dom = tryparse_dayofmonth(dom_str)
        dom !== nothing || throw(ArgumentError("Unable to parse day-of-month: \"$dom_str\""))
        dt = tonext(dom, dt; step=Day(1), same=true)
    end

    dt += shift

    # Note: If the time is UTC, we add back the offset and any saved amount
    # If it's local standard time, we just need to add any saved amount
    # return letter == 's' ? (dt - save) : (dt - offset - save)
    return dt, flag
end

function asutc(dt::DateTime, flag::Char, offset::TimeOffset, save::TimeOffset)
    if flag == 'u'
        # In UTC
        return dt
    elseif flag == 'w'
        # In local wall time, add back offset and saved amount
        return dt - offset - save
    elseif flag == 's'
        # In local standard time, add back any saved amount
        return dt - offset
    else
        error("Unknown flag: $flag")
    end
end

function abbr_string(format::AbstractString, save::TimeOffset, letter::AbstractString="")
    # Note: using @sprintf would make sense but unfortunately it doesn't accept a
    # format as a variable.
    abbr = replace(format, "%s" => letter, count=1)

    # If the abbreviation contains a slash then the first string is the abbreviation
    # for standard time and the second is the abbreviation for daylight saving time.
    abbrs = split(abbr, '/')
    if length(abbrs) > 1
        abbr = save == ZERO ? first(abbrs) : last(abbrs)
    end

    # Some time zones (e.g. "Europe/Ulyanovsk") do not have abbreviations for the various
    # rules and instead hardcode the offset as the name.
    if occursin(r"[+-]\d{2}", abbr)
        abbr = ""
    end

    return abbr
end

function Base.parse(::Type{Rule}, str::AbstractString)
    from_str, to_str, type_str, month_str, on_str, at_str, save_str, letter_str = begin
        split(str, r"\s+")
    end

    from = from_str != "min" ? parse(Int, from_str) : nothing
    to = to_str == "only" ? from : (to_str != "max" ? parse(Int, to_str) : nothing)
    type_str == "-" || throw(ArgumentError("Unhandled rule type: \"$type_str\""))
    month = MONTHS[month_str]

    # Now we need to get the right anonymous function
    # for determining the right day for transitioning
    on = tryparse_dayofmonth(on_str)
    on === nothing && error("Can't parse day of month for DST change: \"$on_str\"")

    # Now we get the time of the transition
    c = at_str[end]
    at = parse(TimeOffset, isflag(c) ? at_str[1:end-1] : at_str)
    at_flag = isflag(c) ? c : DEFAULT_FLAG
    save = parse(TimeOffset, save_str)
    letter = letter_str != "-" ? letter_str : ""

    # Report unexpected save values that could cause issues during resolve.
    save < MIN_SAVE && @warn "Discovered save \"$save_str\" less than the expected min $MIN_SAVE"
    save > MAX_SAVE && @warn "Discovered save \"$save_str\" larger than the expected max $MAX_SAVE"

    # Now we've finally parsed everything we need
    return Rule(from, to, month, on, at, at_flag, save, letter)
end

function Base.parse(::Type{Zone}, str::AbstractString)
    parts = split(str, r"\s+"; limit=4)
    gmtoff_str, rules_str, format_str = parts[1:3]
    until_str = length(parts) > 3 ? parts[4] : ""

    # Get our offset and abbreviation string for this period
    gmt_offset = parse(TimeOffset, gmtoff_str)

    # Report unexpected offsets that could cause issues during resolve.
    gmt_offset < MIN_GMT_OFFSET && @warn "Discovered offset $gmt_offset less than the expected min $MIN_GMT_OFFSET"
    gmt_offset > MAX_GMT_OFFSET && @warn "Discovered offset $gmt_offset larger than the expected max $MAX_GMT_OFFSET"

    # "zzz" represents a NULL entry
    abbr_format = format_str != "zzz" ? format_str : ""

    # Parse the date the line rule applies up to
    until, until_flag = !isempty(until_str) ? parse_date(until_str) : (nothing, 'w')

    if rules_str == "-" || any(isnumeric, rules_str)
        rule_name = nothing
        save_offset = TimeOffset(rules_str)
    else
        rule_name = rules_str
        save_offset = ZERO
    end

    return Zone(gmt_offset, save_offset, rule_name, abbr_format, until, until_flag)
end

"""
Rules are typically ordered by the "from" than "in" fields. Since rules also
contain a "to" field the written ordering can be problematic for resolving
time zone transitions.

Example:

    # Rule  NAME    FROM    TO  TYPE    IN  ON  AT      SAVE    LETTER/S
    Rule    Poland  1918    1919    -   Sep 16  2:00s   0       -
    Rule    Poland  1919    only    -   Apr 15  2:00s   1:00    S
    Rule    Poland  1944    only    -   Apr  3  2:00s   1:00    S

    A simplistic way of iterating through the rules by years could yield the rules
    in the wrong order:

    # ON         AT      SAVE    LETTER/S
    1918-09-16   2:00s   0       -
    1919-09-16   2:00s   0       -
    1919-04-15   2:00s   1:00    S
    1944-04-03   2:00s   1:00    S

    The order_rules function will expand the rules such that they can be ordered by the
    "on" date which ensures we process the rules in the correct order:

    1918-09-16   2:00s   0       -
    1919-04-15   2:00s   1:00    S
    1919-09-16   2:00s   0       -
    1944-04-03   2:00s   1:00    S
"""
function order_rules(rules::Vector{Rule}; max_year::Integer=MAX_YEAR)
    dates = Date[]
    ordered = Rule[]

    # Note: Typically rules are ordered by "from" and "in". Unfortunately
    for rule in rules
        start_year = max(something(rule.from, MIN_YEAR), MIN_YEAR)
        end_year = min(something(rule.to, max_year), max_year)

        # For each year the rule applies compute the transition date
        for rule_year in start_year:end_year
            # Determine the rule transition day by starting at the
            # beginning of the month and applying our "on" function
            # until we reach the correct day.
            date = Date(rule_year, rule.month)
            try
                # The "on" function should evaluate to a day within the current month.
                date = tonext(rule.on, date; same=true, limit=daysinmonth(date))
            catch e
                if isa(e, ArgumentError)
                    error("Unable to find matching day in month $(year(date))/$(month(date))")
                else
                    rethrow(e)
                end
            end
            push!(dates, date)
            push!(ordered, rule)
        end
    end

    perm = sortperm(dates)
    dates = dates[perm]
    ordered = ordered[perm]

    # Since we are not yet taking offsets or flags into account yet
    # there is a small chance that the results are not ordered correctly.
    last_date = typemin(Date)
    for (i, date) in enumerate(dates)
        if i > 1 && date - last_date <= ABS_DIFF_OFFSET
            error("Dates are probably not in order")
        end
        last_date = date
    end

    return dates, ordered
end

"""
Resolves a named zone into TimeZone. Updates ordered with any new rules that
were required to be ordered.
"""
function compile!(
    zone_name::AbstractString,
    tz_source::TZSource,
    ordered::OrderedRuleDict;
    max_year::Integer=MAX_YEAR,
    debug=false,
)
    transitions = Transition[]
    cutoff = nothing

    # Set some default values and starting DateTime increment and away we go...
    start_utc = DateTime(MIN_YEAR)
    max_until = DateTime(max_year) + Year(1) - Second(1)
    save = ZERO
    letter = ""
    start_rule = nothing

    zone_set = tz_source.zones
    rule_set = tz_source.rules

    # zones = Set{FixedTimeZone}()

    # Zone needs to be in ascending order to ensure that start_utc is being applied
    # to the correct transition.
    for zone in sort(zone_set[zone_name])

        # Break at the beginning of the loop instead of the end so that we know an
        # future zone exists beyond max_year and we can set cutoff.
        if year(start_utc) > max_year
            cutoff = start_utc
            break
        end

        offset = zone.gmtoffset
        format = zone.format
        # save = zone.save
        rule_name = zone.rules
        until = something(zone.until, max_until)
        cutoff = nothing  # Reset cutoff

        if rule_name === nothing
            save = zone.save
            abbr = abbr_string(format, save)

            if debug
                rule_name = "\"\""  # Just for display purposes
                println("Zone Start $rule_name, $(zone.gmtoffset), $save, $(start_utc)u, $(until)$(zone.until_flag), $abbr")
            end

            tz = FixedTimeZone(abbr, Second(offset), Second(save))
            if isempty(transitions) || last(transitions).zone != tz
                push!(transitions, Transition(start_utc, tz))
            end
        else
            # Only order the rule if it hasn't already been processed. We'll go one year
            # further than the max_year to ensure we get an accurate cutoff DateTime.
            if !haskey(ordered, rule_name)
                ordered[rule_name] = order_rules(rule_set[rule_name]; max_year=max_year + 1)
            end

            dates, rules = ordered[rule_name]

            # TODO: We could avoid this search if the rule_name haven't changed since the
            # last iteration.
            index = searchsortedlast(dates, start_utc)

            if start_rule !== nothing
                rule = start_rule
                save = rule.save
                letter = rule.letter

                start_rule = nothing
            elseif index == 0
                save = ZERO

                # Find the first occurrence of of standard-time
                for rule in rules
                    if rule.save == save
                        letter = rule.letter
                        break
                    end
                end
            else
                rule = rules[index]
                save = rule.save
                letter = rule.letter
            end
            abbr = abbr_string(format, save, letter)

            debug && println("Zone Start $rule_name, $(zone.gmtoffset), $save, $(start_utc)u, $(until)$(zone.until_flag), $abbr")

            tz = FixedTimeZone(abbr, Second(offset), Second(save))
            if isempty(transitions) || last(transitions).zone != tz
                push!(transitions, Transition(start_utc, tz))
            end

            index = max(index, 1)
            for (date, rule) in zip(dates[index:end], rules[index:end])
                # Add "at" since it could be larger than 23:59:59.
                dt = DateTime(date) + rule.at

                # Convert rule and until datetimes into UTC using the latest
                # offset and save values that occurred prior to this rule.
                dt_utc = asutc(dt, rule.at_flag, offset, save)
                until_utc = asutc(until, zone.until_flag, offset, save)

                if dt_utc == until_utc
                    start_rule = rule
                elseif dt_utc > until_utc
                    cutoff = dt_utc
                end

                dt_utc >= until_utc && break

                # Need to be careful when we update save/letter.
                save = rule.save
                letter = rule.letter
                abbr = abbr_string(format, save, letter)

                if debug
                    status = dt_utc >= start_utc ? "Rule" : "Skip"
                    println("$status $(year(date)), $(dt)$(rule.at_flag), $(dt_utc)u, $save, $abbr")
                end

                # TODO: Is start_utc inclusive or exclusive?
                dt_utc >= start_utc || continue

                tz = FixedTimeZone(abbr, Second(offset), Second(save))

                # TODO: We can maybe reduce memory usage by reusing the same
                # FixedTimeZone object.
                # Note: By default pushing onto a set will replace objects.
                # if !(tz in zones)
                #     push!(zones, tz)
                # else
                #     tz = first(intersect(zones, Set([tz])))
                # end

                if isempty(transitions) || last(transitions).zone != tz
                    push!(transitions, Transition(dt_utc, tz))
                end
            end
        end

        start_utc = asutc(until, zone.until_flag, offset, save)
        debug && println("Zone End   $rule_name, $offset, $save, $(start_utc)u")
    end

    debug && println("Cutoff     $(something(cutoff, "nothing"))")

    # Note: Transitions array is expected to be ordered and should be if both
    # zones and rules were ordered.
    if length(transitions) > 1 || cutoff !== nothing
        return VariableTimeZone(zone_name, transitions, cutoff)
    else
        # Although unlikely the time zone name in the transition and the zone_name
        # could be different.
        offset = first(transitions).zone.offset
        return FixedTimeZone(zone_name, offset)
    end
end


function load!(tz_source::TZSource, io::IO)
    zones = tz_source.zones
    rules = tz_source.rules
    links = tz_source.links

    local kind
    local name

    # For the intial pass we'll collect the zone and rule lines.
    for line in eachline(io)
        # Lines that start with whitespace can be considered a "continuation line" which
        # means the last found kind/name should persist.
        persist = occursin(r"^\s", line)

        line = strip(replace(line, r"#.*$" => ""))
        length(line) > 0 || continue

        if !persist
            kind, name, line = split(line, r"\s+"; limit=3)
        end

        if kind == "Rule"
            rule = parse(Rule, line)
            rules[name] = push!(get(rules, name, Rule[]), rule)
        elseif kind == "Zone"
            zone = parse(Zone, line)
            zones[name] = push!(get(zones, name, Zone[]), zone)
        elseif kind == "Link"
            target = name
            link_name = line
            links[link_name] = target
        else
            @warn "Unhandled line found with type: $kind"
        end
    end

    return tz_source
end

function load!(tz_source::TZSource, file::AbstractString)
    open(file, "r") do io
        load!(tz_source, io)
    end
end

function compile(name::AbstractString, tz_source::TZSource; kwargs...)
    ordered = OrderedRuleDict()
    if haskey(tz_source.links, name)
        tz = compile!(tz_source.links[name], tz_source, ordered; kwargs...)
        rename(tz, name)
    else
        compile!(name, tz_source, ordered; kwargs...)
    end
end

function compile(tz_source::TZSource; kwargs...)
    time_zones = Vector{TimeZone}()
    ordered = OrderedRuleDict()
    lookup = Dict{String, TimeZone}()
    for zone_name in keys(tz_source.zones)
        tz = compile!(zone_name, tz_source, ordered; kwargs...)
        push!(time_zones, tz)
        lookup[zone_name] = tz
    end

    # Convert links into time zones.
    for (link_name, target) in tz_source.links
        if !haskey(lookup, link_name) && haskey(lookup, target)
            push!(time_zones, rename(lookup[target], link_name))
        elseif !haskey(lookup, target)
            error("Unable to resolve link \"$link_name\" referencing \"$target\"")
        end
    end

    return time_zones
end



function compile(tz_source_dir::AbstractString=TZ_SOURCE_DIR, dest_dir::AbstractString=COMPILED_DIR; max_year::Integer=MAX_YEAR)
    tz_source_paths = joinpath.(tz_source_dir, readdir(tz_source_dir))
    time_zones = compile(TZSource(tz_source_paths); max_year=max_year)

    isdir(dest_dir) || error("Destination directory doesn't exist")
    empty!(TIME_ZONES)

    for tz in time_zones
        parts = split(TimeZones.name(tz), '/')
        tz_path = joinpath(dest_dir, parts...)
        tz_dir = dirname(tz_path)

        isdir(tz_dir) || mkpath(tz_dir)

        open(tz_path, "w") do fp
            serialize(fp, tz)
        end
    end
end
