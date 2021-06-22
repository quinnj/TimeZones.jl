module TZData

using Printf
using RelocatableFolders
using ...TimeZones: DEPS_DIR

import Pkg

if VERSION >= v"1.3"
    using ...TimeZones: @artifact_str
    using Pkg.Artifacts: artifact_hash
end

# Note: The tz database is made up of two parts: code and data. TimeZones.jl only requires
# the "tzdata" archive or more specifically the "tz source" files within the archive
# (africa, australasia, ...)

const ARCHIVE_DIR = @path joinpath(DEPS_DIR, "tzarchive")
const TZ_SOURCE_DIR = @path joinpath(DEPS_DIR, "tzsource")
const COMPILED_DIR = @path joinpath(DEPS_DIR, "compiled", string(VERSION))

const ARTIFACT_TOML = @path joinpath(@__DIR__, "..", "..", "Artifacts.toml")

export ARCHIVE_DIR, TZ_SOURCE_DIR, COMPILED_DIR, REGIONS, LEGACY_REGIONS

if Sys.iswindows()
    if isdefined(Base, :LIBEXECDIR)
        const exe7z = joinpath(Sys.BINDIR, Base.LIBEXECDIR, "7z.exe")
    else
        const exe7z = joinpath(Sys.BINDIR, "7z.exe")
    end
end

include("timeoffset.jl")
include("archive.jl")
include("version.jl")
include("download.jl")
include("compile.jl")
include("build.jl")
include("deprecated.jl")

end
