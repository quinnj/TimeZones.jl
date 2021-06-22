# `RelocatableFolders.@path` requires the existance of the referenced root
# directory/file.  We ensure they exist prior to calling `using TimeZones`.
mkpath(joinpath(@__DIR__, "tzarchive"))
mkpath(joinpath(@__DIR__, "compiled", string(VERSION)))
touch(joinpath(@__DIR__, "active_version"))
touch(joinpath(@__DIR__, "latest"))

using TimeZones: build

build()
