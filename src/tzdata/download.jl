using Dates
using TimeZones: DEPS_DIR

if VERSION >= v"1.6.0-DEV.923"
    # Use Downloads.jl once TimeZones.jl drops support for Julia versions < 1.3
    download(args...) = Base.invokelatest(Base.Downloads().download, args...)
else
    using Base: download
end

const LATEST_FILE = @path joinpath(DEPS_DIR, "latest")
const LATEST_FORMAT = Dates.DateFormat("yyyy-mm-ddTHH:MM:SS")
const LATEST_DELAY = Hour(1)  # In 1996 a correction to a release was made an hour later

function read_latest(io::IO)
    version = readline(io)
    retrieved_utc = DateTime(readline(io), LATEST_FORMAT)
    return version, retrieved_utc
end

function read_latest(filename::AbstractString)
    open(filename, "r") do io
        read_latest(io)
    end
end

function write_latest(io::IO, version::AbstractString, retrieved_utc::DateTime=now(Dates.UTC))
    write(io, version)
    write(io, "\n")
    write(io, Dates.format(retrieved_utc, LATEST_FORMAT))
end

const LATEST = let T = Tuple{AbstractString, DateTime}
    isfile(LATEST_FILE) ? Ref{T}(read_latest(LATEST_FILE)) : Ref{T}()
end

function set_latest_cached(version::AbstractString, retrieved_utc::DateTime=now(Dates.UTC))
    LATEST[] = version, retrieved_utc
    open(LATEST_FILE, "w") do io
        write_latest(io, version, retrieved_utc)
    end
end

function latest_cached(now_utc::DateTime=now(Dates.UTC))
    if isassigned(LATEST)
        latest_version, latest_retrieved_utc = LATEST[]

        if now_utc - latest_retrieved_utc < LATEST_DELAY
            return latest_version
        end
    end

    return nothing
end

"""
    tzdata_versions() -> Vector{String}

Retrieves all of the currently available tzdata versions from IANA. The version list is
ordered from earliest to latest.

# Examples
```julia
julia> last(tzdata_versions())  # Current latest available tzdata version
"2020a"
```
"""
function tzdata_versions()
    releases_file = download("https://data.iana.org/time-zones/releases/")

    html = try
        read(releases_file, String)
    finally
        rm(releases_file)
    end

    versions = [
        m[:version]
        for m in eachmatch(r"href=\"tzdata(?<version>(?:\d{2}){1,2}[a-z]?).tar.gz\"", html)
    ]

    # Correctly order releases which include 2-digit years (e.g. "96")
    sort!(versions, by=v -> length(v) < 5 ? "19$v" : v)

    return versions
end

"""
    tzdata_url(version="latest") -> AbstractString

Generates a HTTPS URL for the specified tzdata version. Typical version strings are
formatted as 4-digit year followed by a lowercase ASCII letter. Available versions start
with "tzdata" and are listed on "https://data.iana.org/time-zones/releases/" or
"ftp://ftp.iana.org/tz/releases/".

# Examples
```julia
julia> tzdata_url("2017a")
"https://data.iana.org/time-zones/releases/tzdata2017a.tar.gz"
```
"""
function tzdata_url(version::AbstractString="latest")
    # Note: We could also support FTP but the IANA server is unreliable and likely
    # to break if working from behind a firewall.
    if version == "latest"
        "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
    else
        "https://data.iana.org/time-zones/releases/tzdata$version.tar.gz"
    end
end

"""
    tzdata_download(version="latest", dir=tempdir()) -> AbstractString

Downloads a tzdata archive from IANA using the specified `version` to the specified
directory. See `tzdata_url` for details on tzdata version strings.
"""
function tzdata_download(version::AbstractString="latest", dir::AbstractString=tempdir())
    now_utc = now(Dates.UTC)
    if version == "latest"
        latest_version = latest_cached(now_utc)
        if latest_version !== nothing
            archive = joinpath(dir, "tzdata$(latest_version).tar.gz")
            isfile(archive) && return archive
        end
    end

    url = tzdata_url(version)
    archive = download(url, joinpath(dir, basename(url)))  # Overwrites the local file if any

    # Note: An "HTTP 404 Not Found" may result in the 404 page being downloaded. Also,
    # catches issues with corrupt archives
    if !isarchive(archive)
        rm(archive)
        error("Unable to download $version tzdata")
    end

    # Rename the file to have an explicit version
    if version == "latest"
        version = tzdata_version_archive(archive)

        archive_versioned = joinpath(dir, "tzdata$version.tar.gz")
        mv(archive, archive_versioned, force=true)
        archive = archive_versioned

        set_latest_cached(version, now_utc)
    end

    return archive
end
