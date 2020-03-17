@testset "ZonedDateTime plot recipe" begin
    start_zdt = ZonedDateTime(2017,1,1,0,0,0, tz"EST")
    end_zdt = ZonedDateTime(2017,1,1,10,30,0, tz"EST")
    zoned_dates = start_zdt:Hour(1):end_zdt

    function check_extrema(x_axis)
        date_val(zdt) = Dates.value(DateTime(zdt, Local))

        @test x_axis[:extrema].emin ≈ date_val(start_zdt) rtol=0.000_000_1
        @test x_axis[:extrema].emax ≈ date_val(end_zdt) rtol=0.000_000_1
    end

    @testset "No label" begin
        result = scatter(zoned_dates, 1:11)
        x_axis = result.subplots[1][:xaxis]
        check_extrema(x_axis)
        @test x_axis[:guide] == "(timezone: EST)"
    end

    @testset "label" begin
        result = scatter(zoned_dates, 1:11; xlabel="Hi")
        x_axis = result.subplots[1][:xaxis]
        check_extrema(x_axis)
        @test x_axis[:guide] == "Hi (timezone: EST)"
    end

    @testset "No items" begin
        empty_xs = ZonedDateTime[]
        empty_ys = 0:-1
        result = scatter(empty_xs, empty_ys; xlabel="Hi")
        @test result isa Plots.Plot  # make sure doesn't error
    end
end
