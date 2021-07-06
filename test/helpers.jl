# Utility functions for testing

function ignore_output(body::Function; stdout::Bool=true, stderr::Bool=true)
    out_old = Base.stdout
    err_old = Base.stderr

    if stdout
        (out_rd, out_wr) = redirect_stdout()
    end
    if stderr
        (err_rd, err_wr) = redirect_stderr()
    end

    result = try
        body()
    finally
        if stdout
            redirect_stdout(out_old)
            close(out_wr)
            close(out_rd)
        end
        if stderr
            redirect_stderr(err_old)
            close(err_wr)
            close(err_rd)
        end
    end

    return result
end

# Used in tests as a shorter form of: `sprint(show, ..., context=:compact => true)`
show_compact = (io, args...) -> show(IOContext(io, :compact => true), args...)

# Takes the tuple from `compile` and adds the result into TimeZones cache. Typically should
# not be used and only should be required if the test tzdata version and built tzdata
# version do not match.
function cache_tz((tz, class)::Tuple{TimeZone, TimeZones.Class})
    TimeZones.default_tz_cache()[TimeZones.name(tz)] = (tz, class)
    return tz
end
