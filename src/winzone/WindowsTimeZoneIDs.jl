module WindowsTimeZoneIDs

using ...TimeZones: DEPS_DIR
using EzXML
using RelocatableFolders

if VERSION >= v"1.3"
    using ...TimeZones: @artifact_str
end

const UNICODE_CLDR_VERSION = "release-37"

# A mapping of Windows timezone names to Olson timezone names.
# Details on the contents of this file can be found at:
# http://cldr.unicode.org/development/development-process/design-proposals/extended-windows-olson-zid-mapping
const WINDOWS_ZONE_URL = "https://raw.githubusercontent.com/unicode-org/cldr/$UNICODE_CLDR_VERSION/common/supplemental/windowsZones.xml"
const WINDOWS_ZONE_FILE = joinpath("cldr-$UNICODE_CLDR_VERSION", "common", "supplemental", "windowsZones.xml")

const WINDOWS_XML_DIR = @path joinpath(DEPS_DIR, "local")
const WINDOWS_XML_FILE = @path joinpath(WINDOWS_XML_DIR, "windowsZones.xml")

isdir(WINDOWS_XML_DIR) || mkdir(WINDOWS_XML_DIR)

function compile(xml_file::AbstractString)
    # Get the timezone conversions from the file
    doc = readxml(xml_file)

    # Territory "001" is the global default
    map_zones = findall("//mapZone[@territory='001']", doc)

    # TODO: Eliminate the Etc/* POSIX names here? See Windows section of `localzone`

    # Dictionary to store the windows to time zone conversions
    translation = Dict{String,String}()
    for map_zone in map_zones
        win_name = map_zone["other"]
        posix_name = map_zone["type"]
        translation[win_name] = posix_name
    end

    return translation
end

const WINDOWS_TRANSLATION = if isfile(WINDOWS_XML_FILE)
    compile(WINDOWS_XML_FILE)
else
    Dict{AbstractString, AbstractString}()
end

function build(xml_file::AbstractString=WINDOWS_XML_FILE; force::Bool=false)
    fallback_xml_file = joinpath(WINDOWS_XML_DIR, "windowsZones2017a.xml")

    if !isfile(xml_file)
        if isfile(fallback_xml_file) && !force
            cp(fallback_xml_file, xml_file)
        else
            @info "Downloading Windows to POSIX timezone ID XML version: $UNICODE_CLDR_VERSION"
            @static if VERSION >= v"1.3"
                artifact_dir = @artifact_str "unicode-cldr-$UNICODE_CLDR_VERSION"
                xml_file = joinpath(artifact_dir, WINDOWS_ZONE_FILE)
            else
                download(WINDOWS_ZONE_URL, xml_file)
            end
        end
    end

    @info "Compiling Windows time zone name translation"
    translation = compile(xml_file)

    # Copy contents into translation constant
    empty!(WINDOWS_TRANSLATION)
    for (k, v) in translation
        WINDOWS_TRANSLATION[k] = v
    end
end

end
