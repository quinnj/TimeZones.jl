const TIME_ZONE_CACHE = Dict{String,Tuple{TimeZone,Class}}()

"""
    TimeZone(str::AbstractString) -> TimeZone

Constructs a `TimeZone` subtype based upon the string. If the string is a recognized
standard time zone name then data is loaded from the compiled IANA time zone database.
Otherwise the string is parsed as a fixed time zone.

A list of recognized standard and legacy time zones names can is available by running
`timezone_names()`. Supported fixed time zone string formats can be found in docstring for
[`FixedTimeZone(::AbstractString)`](@ref).

## Examples
```jldoctest
julia> TimeZone("Europe/Warsaw")
Europe/Warsaw (UTC+1/UTC+2)

julia> TimeZone("UTC")
UTC
```
"""
TimeZone(::AbstractString)

"""
    TimeZone(str::AbstractString, mask::Class) -> TimeZone

Similar to [`TimeZone(::AbstractString)`](@ref) but allows you to control what time zone
classes are allowed to be constructed with `mask`. Can be used to construct time zones
which are classified as "legacy".

## Examples
```jldoctest
julia> TimeZone("US/Pacific")
ERROR: ArgumentError: The time zone "US/Pacific" is of class `TimeZones.Class(:LEGACY)` which is currently not allowed by the mask: `TimeZones.Class(:FIXED) | TimeZones.Class(:STANDARD)`

julia> TimeZone("US/Pacific", TimeZones.Class(:LEGACY))
US/Pacific (UTC-8/UTC-7)
```
"""
TimeZone(::AbstractString, ::Class)

function TimeZone(str::AbstractString, mask::Class=Class(:DEFAULT))
    # Note: If the class `mask` does not match the time zone we'll still load the
    # information into the cache to ensure the result is consistent.
    tz, class = get!(TIME_ZONE_CACHE, str) do
        tz_path = joinpath(TZData.COMPILED_DIR, split(str, "/")...)

        if mask == Class(:DEFAULT) && is_standard_iana(str)
            # TODO: idk if this as sensible way to handle class and mask
            get_iana_timezone!(str), Class(:DEFAULT)
        elseif isfile(tz_path)
            open(deserialize, tz_path, "r")
        elseif occursin(FIXED_TIME_ZONE_REGEX, str)
            FixedTimeZone(str), Class(:FIXED)
        elseif !isdir(TZData.COMPILED_DIR) || isempty(readdir(TZData.COMPILED_DIR))
            # Note: Julia 1.0 supresses the build logs which can hide issues in time zone
            # compliation which result in no tzdata time zones being available.
            throw(ArgumentError(
                "Unable to find time zone \"$str\". Try running `TimeZones.build()`."
            ))
        else
            throw(ArgumentError("Unknown time zone \"$str\""))
        end
    end

    if mask & class == Class(:NONE)
        throw(ArgumentError(
            "The time zone \"$str\" is of class `$(repr(class))` which is " *
            "currently not allowed by the mask: `$(repr(mask))`"
        ))
    end

    return tz
end

"""
    @tz_str -> TimeZone

Constructs a `TimeZone` subtype based upon the string at parse time. See docstring of
`TimeZone` for more details.

```julia
julia> tz"Africa/Nairobi"
Africa/Nairobi (UTC+3)
```
"""
macro tz_str(str)
    TimeZone(str)
end

"""
    istimezone(str::AbstractString, mask::Class=Class(:DEFAULT)) -> Bool

Check whether a string is a valid for constructing a `TimeZone` with the provided `mask`.
"""
function istimezone(str::AbstractString, mask::Class=Class(:DEFAULT))
    # Start by performing quick FIXED class test
    if mask & Class(:FIXED) != Class(:NONE) && occursin(FIXED_TIME_ZONE_REGEX, str)
        return true
    end

    # Perform more expensive checks against pre-compiled time zones
    tz, class = get(TIME_ZONE_CACHE, str) do
        tz_path = joinpath(TZData.COMPILED_DIR, split(str, "/")...)

        if isfile(tz_path)
            # Cache the data since we're already performing the deserialization
            TIME_ZONE_CACHE[str] = open(deserialize, tz_path, "r")
        else
            nothing, Class(:NONE)
        end
    end

    return tz !== nothing && mask & class != Class(:NONE)
end

# After `broadcastable` was defined but before this was addressed in the `Dates` stdlib
# - Broadcastable introduction: https://github.com/JuliaLang/julia/pull/26601
# - Fixed in Dates: https://github.com/JuliaLang/julia/pull/30159
# Note: The change was backported to 1.1 as well.
if v"0.7.0-DEV.4743" <= VERSION < v"1.1.0-DEV.722" || v"1.2-" <= VERSION < v"1.2.0-DEV.114"
    Base.broadcastable(tz::TimeZone) = Ref(tz)
end
