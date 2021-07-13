@testset "VariableTimeZone" begin
    @testset "equality" begin
        warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))
        another_warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))

        @test warsaw == warsaw
        @test warsaw === warsaw
        @test warsaw == another_warsaw
        @test warsaw !== another_warsaw
        @test isequal(warsaw, another_warsaw)
        @test hash(warsaw) == hash(another_warsaw)
    end

    @testset "broadcastable" begin
        warsaw = first(compile("Europe/Warsaw", tzdata["europe"]))

        # Validate that VariableTimeZone is treated as a scalar during broadcasting
        @test size(warsaw .== warsaw) == ()
    end

    @testset "links" begin
        # "Arctic/Longyearbyen" is a link to "Europe/Oslo"
        oslo = first(compile("Europe/Oslo", tzdata["europe"]))
        longyearbyen = first(compile("Arctic/Longyearbyen", tzdata["europe"]))

        @test oslo.name != longyearbyen.name
        @test oslo.transitions == longyearbyen.transitions
        @test oslo.cutoff == longyearbyen.cutoff

        @test oslo != longyearbyen
        @test oslo !== longyearbyen
        @test !isequal(oslo, longyearbyen)
        @test hash(oslo) != hash(longyearbyen)
    end

    @testset "cutoff differs" begin
        a = first(compile("Europe/Warsaw", tzdata["europe"]))
        b = VariableTimeZone(a.name, a.transitions, nothing)

        @test a.name == b.name
        @test a.transitions == b.transitions
        @test a.cutoff != b.cutoff

        @test a == b
        @test a !== b
        @test !isequal(a, b)
        @test hash(a) == hash(b)
    end

    @testset "hash using name" begin
        a = first(compile("Europe/Warsaw", tzdata["europe"]))
        b = VariableTimeZone("Europe/Warsaw", a.transitions[1:1], nothing)

        # To be fast the `hash` function only uses the name. However, when a hash collision
        # does occur it should be disambiguated by the `isequal` check which also considers
        # the transition and the cutoff.
        @test hash(a) == hash(b)
        @test !isequal(a, b)
        @test length(keys(Dict(a => :a, b => :b))) == 2  # Time zones use different keys
    end
end
