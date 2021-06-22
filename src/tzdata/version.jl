# Default tzdata version to use if the environmental variable "JULIA_TZ_VERSION" is not set.
# We want to use a specific version here to ensure that specific revisions of the
# TimeZones.jl package always use the same revision of tzdata. Doing so ensure that we can
# always use older revisions of this package and always reproduce the same results.
const DEFAULT_TZDATA_VERSION = "2021a"  # Do not use floating revision "latest" here


# Note: A tz code or data version consists of a year and letter while a release consists of
# a pair of tz code and data versions. In recent releases the tz code and data use the same
# version.
#
# > Typically a release R consists of a pair of tarball files,
# > tzcodeR.tar.gz and tzdataR.tar.gz.  However, some releases (e.g.,
# > code2010a, data2012c) consist of just one or the other tarball, and a
# > few (e.g., code2012c-data2012d) have tarballs with mixed version
# > numbers.
#
# ―NEWS file (tzdata2017a)

# Parse the tzdata version from things such as the archive filename
const TZDATA_VERSION_REGEX = r"(?<!\d)(?:\d{2}){1,2}[a-z]?\b"

# Parse release lines from the NEWS file
const TZDATA_NEWS_REGEX = r"""
    ^Release\s+
    (?:code(?:\d{2}){1,2}[a-z]?-)?
    (?:data)?
    (?<version>(?:\d{2}){1,2}[a-z]?)
    \b
"""x

const ACTIVE_VERSION_FILE = @path joinpath(DEPS_DIR, "active_version")


"""
    read_news(news, [limit]) -> Vector{AbstractString}

Reads all of the tzdata versions from the NEWS file in the order in which they appear. Note
that since the NEWS file is in reverse chronological order the versions will also be in that
order. Useful for identifying the version of the tzdata.
"""
function read_news(news::IO, limit::Integer=0)
    count = 0
    revs = sizehint!(AbstractString[], limit)
    while !eof(news) && (limit == 0 || count < limit)
        line = readline(news)

        m = match(TZDATA_NEWS_REGEX, line)
        if m !== nothing
            push!(revs, m[:version])
            count += 1
        end
    end
    return revs
end

function read_news(news::AbstractString, limit::Integer=0)
    open(news, "r") do fp
        read_news(fp, limit)
    end
end

"""
    tzdata_version_dir(dir::AbstractString) -> AbstractString

Determines the tzdata version by inspecting various files in a directory.
"""
function tzdata_version_dir(dir::AbstractString)
    return cd(dir) do
        if isfile("version")  # Added in release 2016h
            readchomp("version")
        elseif isfile("NEWS")
            # Find the archive version by determining the latest version in the change log
            first(read_news("NEWS", 1))  # Added in release 2014g
        else
            error("Unable to determine tzdata version")
        end
    end
end

"""
    tzdata_version_archive(archive::AbstractString) -> AbstractString

Determines the tzdata version by inspecting the contents within the archive. Useful when
downloading the latest archive "tzdata-latest.tar.gz".
"""
function tzdata_version_archive(archive::AbstractString)
    # Attempting to extract files that do not exist in the archive will result in an
    # exception.
    files = readarchive(archive)
    available_files = intersect(Set(["NEWS", "version"]), Set(files))
    isempty(available_files) && error("Unable to determine tzdata release")

    mktempdir() do temp_dir
        extract(archive, temp_dir, available_files)
        tzdata_version_dir(temp_dir)
    end
end

tzdata_version() = get(ENV, "JULIA_TZ_VERSION", DEFAULT_TZDATA_VERSION)

function active_version()
    if !isfile(ACTIVE_VERSION_FILE)
        error("No active tzdata version. Try re-building TimeZones")
    end
    read(ACTIVE_VERSION_FILE, String)
end

function active_archive()
    version = active_version()
    archive = joinpath(ARCHIVE_DIR, "tzdata$version.tar.gz")
    !isfile(archive) && error("Missing $version tzdata archive")
    return archive
end
