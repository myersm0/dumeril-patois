using Test
using DumerilPatois
using DumerilPatois: load_closed_sets, parse_entries, Standard, Locution, Unclassified

const test_directory = @__DIR__
const fixtures_path = joinpath(test_directory, "fixtures", "sample_entries.md")
const closed_sets_path = joinpath(test_directory, "..", "config", "closed_sets.toml")

@testset "smoke_parse" begin
	closed_sets = load_closed_sets(closed_sets_path)
	text = read(fixtures_path, String)
	entries = parse_entries(text, closed_sets)
	by_headword = Dict(entry.headword_raw => entry for entry in entries)

	@testset "Standard with POS + region (Abaisse)" begin
		entry = by_headword["Abaisse"]
		@test entry.kind isa Standard
		@test entry.headword_normalized == "abaisse"
		@test entry.pos_raw == "s. f."
		@test length(entry.pos_tags) == 1
		@test entry.pos_tags[1].pos == "noun"
		@test entry.pos_tags[1].gender == "feminine"
		@test entry.region_raw == "arr. de Mortain"
		@test entry.regions == ["arrondissement_de_mortain"]
	end

	@testset "Multi-headword (Acam et Cam)" begin
		entry = by_headword["Acam"]
		@test entry.kind isa Standard
		@test entry.pos_raw == "prép."
		@test entry.pos_tags[1].pos == "preposition"
		@test length(entry.aliases) == 1
		@test entry.aliases[1].raw == "Cam"
		@test entry.aliases[1].normalized == "cam"
	end

	@testset "Locution-paren (Aboulez-ci-gau)" begin
		entry = by_headword["Aboulez-ci-gau"]
		@test entry.kind isa Locution
		@test entry.regions == ["arrondissement_de_valognes"]
		@test entry.headword_normalized == "aboulez-ci-gau"
	end

	@testset "Standard, no POS, no region (Vréda)" begin
		entry = by_headword["Vréda"]
		@test entry.kind isa Standard
		@test entry.pos_raw === nothing
		@test isempty(entry.pos_tags)
		@test isempty(entry.regions)
		@test entry.headword_normalized == "vreda"
	end

	@testset "Standard, no POS, with region (Moret/Mouret)" begin
		entry = by_headword["Moret"]
		@test entry.kind isa Standard
		@test entry.pos_raw === nothing
		@test isempty(entry.pos_tags)
		@test entry.regions == ["arrondissement_de_bayeux"]
		@test length(entry.aliases) == 1
		@test entry.aliases[1].raw == "Mouret"
	end

	@testset "Unclassified (Mon)" begin
		entry = by_headword["Mon"]
		@test entry.kind isa Unclassified
		@test entry.headword_qualifier == "c'est"
	end

	@testset "Headword qualifier with POS following (Havet)" begin
		entry = by_headword["Havet"]
		@test entry.kind isa Standard
		@test entry.headword_qualifier == "Bête"
		@test entry.pos_raw == "s. f."
		@test entry.regions == ["arrondissement_de_valognes"]
	end

	@testset "Bold-token-in-paren as alias (Carpeleuse)" begin
		entry = by_headword["Carpeleuse"]
		@test entry.kind isa Standard
		@test length(entry.aliases) == 1
		@test entry.aliases[1].raw == "Chapeleuse"
		@test entry.aliases[1].normalized == "chapeleuse"
		@test entry.pos_raw == "s. f."
		@test entry.regions == ["arrondissement_de_bayeux"]
	end

	@testset "Citation rejection (Benois)" begin
		@test !haskey(by_headword, "Benois")
		@test occursin("Benois", by_headword["Foo"].body)
		@test haskey(by_headword, "Bar")
	end

	@testset "ERRATA terminator" begin
		@test haskey(by_headword, "Ziguer")
		@test !haskey(by_headword, "ShouldNotAppear")
		@test !haskey(by_headword, "Arronce")
		@test !haskey(by_headword, "Arrousse")
	end
end
