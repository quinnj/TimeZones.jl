const IANA_TABLE_SIZE = 1680

perfect_hash(tz::VariableTimeZone) = perfect_hash(tz.name)
function perfect_hash(str::AbstractString)
    # This was generated via `gperf` and translated by hand.
    # in case of collisions from new keys being added you must *not* regenerate it or
    # change the assoc table, as that will change existing hashes and break any serialized
    # data. Instead add special cases from the exact string via adding special cases. e.g.
    #`name=="New/Timezone" && return 1681` (after adjusting `IANA_TABLE_SIZE`)
    # The code below will (for all timezones in the 2021a release of tzdata) generate a
    # value between 29 and 1680 inclusive. So any new keys that need to be added
    # manually  to resolve collisions can freely use anything outside that range.

    asso_values = (
      # this contains exactly 127 (ie. 0x7F) values. this is important for speed and for
      # the inbounds checking after
      1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681,
      1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681,
      1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681,
      1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681, 1681,
      1681, 1681, 1681,    4, 1681,    1,    3,    3,  241,   48,
         1,   22,   10,    9,   61,   18,   74,    9,   30, 1681,
      1681, 1681, 1681, 1681, 1681,    4,    2,   18,  167,   48,
       547,  691,  532,  446,  574,  466,  211,  452,    8,  387,
       110,  475,  601,  262,   83,  124,  580,  536,   60,    1,
       719,    2, 1681, 1681, 1681,  291,    1,    1,   27,  424,
        13,    5,   43,    3,  355,   12,  168,  148,   90,  179,
         4,    1,  315,    3,    3,    3,    2,   37,    5,   65,
        22,  320,  245,    1, 1681, 1681, 1681, 1681,
    )

    units = codeunits(str)
    len = length(units)

    for unit in units
        # Check every unit is inbounds, if not then we know it is not in the table
        # so return a value that is large to be in the table.
        # It is faster to precheck if these are inbounds in advance and then `@inbounds` the
        # next section.
        unit + 0x01 < UInt(length(asso_values)) || return IANA_TABLE_SIZE + 1
    end

    hval = len
    @inbounds begin
        len >= 19 && (hval += asso_values[units[19]])
        len >= 12 && (hval += asso_values[units[12]])
        len >= 11 && (hval += asso_values[units[11]])
        len >= 9 && (hval += asso_values[units[9] + 1])
        len >= 8 && (hval += asso_values[units[8]])
        len >= 6 && (hval += asso_values[units[6] + 1])
        len >= 4 && (hval += asso_values[units[4]])
        len >= 2 && (hval += asso_values[units[2] + 1])
        len >= 1 && (hval += asso_values[units[1]])
        len > 0 && (hval += asso_values[units[end]])  # add the last
    end
    return hval
end


const IANA_TIMEZONES = Vector{VariableTimeZone}(undef, IANA_TABLE_SIZE)

# TODO: maybe fill this during build(), probably by generating a julia file.
const IANA_NAMES = Vector{String}(undef, IANA_TABLE_SIZE)
function init_IANA_NAMES!()  # this is run by __init__ (at least for now)
    for name in timezone_names()
        id = perfect_hash(name)
        # Important: this line makes sure our hash is indeed perfect
        isassigned(IANA_NAMES, id) && error("hash collision for $tz, at $id")
        IANA_NAMES[id] = name
    end
    return IANA_NAMES
end

function is_standard_iana(str::AbstractString)
    id = perfect_hash(str)
    return isassigned(IANA_NAMES, id) && IANA_NAMES[id] == str
end

function get_iana_timezone!(str::AbstractString)
    id = perfect_hash(str)
    if isassigned(IANA_TIMEZONES, id)
        IANA_TIMEZONES[id]
    else
        tz_path = joinpath(TZData.COMPILED_DIR, split(str, "/")...)
        tz, class = deserialize(tz_path)
        if tz isa VariableTimeZone
            IANA_TIMEZONES[id] = tz
            return IANATimeZone(perfect_hash(str))
        else
            # it is a FixedTimeZone, we are not going to use a IANATimeZone
            return tz
        end
    end
end

function get_iana_timezone!(id::UInt)
    if isassigned(IANA_NAMES, id)
        name = IANA_NAMES[id]
        return get_iana_timezone!(name)
    else
        error(
            "$id does not correspond to any known IANA timezone. " *
            "Check you are using the right version of the IANA database.",
        )
    end
end


"""
    IANATimeZone(::AbstractString) <: AbstractVariableTimeZone

A type for representing a standard variable IANA TimeZome from the tzdata.
Under-the-hood it stores only a unique integer identifier.
"""
struct IANATimeZone <: TimeZone
    # id must be a prefect_hash of the corresponding timezone name
    id::UInt
end

function IANATimeZone(name::AbstractString)
    return IANATimeZone(perfect_hash(name))
end

backing_timezone(itz::IANATimeZone) = get_iana_timezone!(itz.id)::VariableTimeZone

Base.:(==)(a::IANATimeZone, b::IANATimeZone) = a.id == b.id
Base.:(==)(a::IANATimeZone, b::TimeZone) = backing_timezone(a) == b
Base.:(==)(b::TimeZone, a::IANATimeZone) = backing_timezone(a) == b

# We can't use our perfect hash is as won't agree with the hash of the backing_timezone
Base.hash(a::IANATimeZone, seed::UInt) = hash(backing_timezone(a), seed)

name(a::IANATimeZone) = name(backing_timezone(a))
transitions(tz::IANATimeZone) = transitions(backing_timezone(tz))

# TODO: should i just make this check the fields of VariableTimeZone and just delegate all?
function Base.getproperty(tz::IANATimeZone, s::Symbol)
    if s === :name
        return name(tz)
    elseif s == :transitions
        return transitions(tz)
    else
        return getfield(tz, s)
    end
end
if isdefined(Base, :hasproperty)
    function Base.hasproperty(tz::IANATimeZone, s::Symbol)
        return s === :name || s === :transitions || hasfield(IANATimeZone, s)
    end
end




""""
    _do_and_rewrap(f, arg1, tz::IANATimeZone, args...; kwargs...)

Run the function `f(arg1, backing_timezone(tz), args...; kwargs...)`
which must return a `ZonedDateTime`, with the backing timezone.
Replace the timezone field with `tz` (which should be equivalent).
"""
function _do_and_rewrap(f, arg1, tz::IANATimeZone, args...; kwargs...)
    backed_tz = backing_timezone(tz)
    backed_zdt::ZonedDateTime = f(arg1, backing_timezone(tz), args...; kwargs...)
        # make it store tz rather than the equiv backing timezone, other fields the same
    return ZonedDateTime(backed_zdt.utc_datetime, tz, backed_zdt.zone)
end


Base.show(io::IO, tz::IANATimeZone) = show(io, backing_timezone(tz))
Base.print(io::IO, tz::IANATimeZone) = print(io, backing_timezone(tz))
