using Mocking

using RecipesBase
using Test
using TimeZones
using TimeZones: PKG_DIR
using TimeZones.TZData: ARCHIVE_DIR, TZSource, compile, build
using Unicode

Mocking.activate()


const TZDATA_VERSION = "2016j"
const TZ_SOURCE_DIR = get(ENV, "TZ_SOURCE_DIR", joinpath(PKG_DIR, "test", "tzsource"))
const TZFILE_DIR = joinpath(PKG_DIR, "test", "tzfile")
const TEST_REGIONS = ["asia", "australasia", "europe", "northamerica"]

# https://github.com/JuliaLang/julia/pull/27900
if VERSION < v"1.2.0-DEV.642"
    const ProcessFailedException = ErrorException
end

isdir(ARCHIVE_DIR) || mkdir(ARCHIVE_DIR)
isdir(TZ_SOURCE_DIR) || mkdir(TZ_SOURCE_DIR)

# By default use a specific version of the tz database so we just testing for TimeZones.jl
# changes and not changes to the tzdata.
build(TZDATA_VERSION, TEST_REGIONS, ARCHIVE_DIR, TZ_SOURCE_DIR)

# For testing we'll reparse the tzdata every time to instead of using the serialized data.
# This should make the development/testing cycle simplier since you won't be forced to
# re-build the cache every time you make a change.
#
# Note: resolving only the time zones we want is much faster than running compile which
# recompiles all the time zones.
tzdata = Dict{String,TZSource}()
for name in TEST_REGIONS
    tzdata[name] = TZSource(joinpath(TZ_SOURCE_DIR, name))
end

include("helpers.jl")

@testset "TimeZones" begin
    include("utils.jl")
    include("indexable_generator.jl")

    include("class.jl")
    include(joinpath("tzdata", "timeoffset.jl"))
    include(joinpath("tzdata", "archive.jl"))
    include(joinpath("tzdata", "version.jl"))
    include(joinpath("tzdata", "download.jl"))
    include(joinpath("tzdata", "compile.jl"))
    Sys.iswindows() && include(joinpath("winzone", "WindowsTimeZoneIDs.jl"))
    include("utcoffset.jl")
    include(joinpath("types", "timezone.jl"))
    include(joinpath("types", "fixedtimezone.jl"))
    include(joinpath("types", "variabletimezone.jl"))
    include(joinpath("types", "zoneddatetime.jl"))
    include("exceptions.jl")
    include("interpret.jl")
    include("accessors.jl")
    include("arithmetic.jl")
    include("io.jl")
    include("tzfile.jl")
    include("adjusters.jl")
    include("conversions.jl")
    include("ranges.jl")
    include("tz_env.jl")
    include("local.jl")
    include("local_mocking.jl")
    include("discovery.jl")
    include("rounding.jl")
    include("parse.jl")
    include("plotting.jl")
    include("thread-safety.jl")

    # Note: Run the build tests last to ensure that re-compiling the time zones files
    # doesn't interfere with other tests.
    if lowercase(get(ENV, "CI", "false")) == "true"
        include("ci.jl")
    end
end
