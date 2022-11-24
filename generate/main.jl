using Pkg: Pkg
Pkg.activate(@__DIR__)
using Cascadia
using Gumbo
using CSV
using Markdown
using Downloads: download

include("piracy.jl")

function main()
    @info "starting"
    open(joinpath(dirname(@__DIR__), "README.md"), "w") do fh
        println(
            fh,
            """
            Hello there 👋

            My name is Miha, I am a physicist turned research software engineer. Feel encouraged to reach out in arbitrary digital ways. Some things we could talk about are:
            - the Julia language
            - who is going to win Wimbledon this year
            - [preferred] the cool thing you are working on
            - some of the things I've done in the past, which include Higgs physics at the ATLAS experiment, and optimising electricity grids.
            """
        )

        println(
            fh,
            """
            Projects I've contributed to in the past include work on the Julia AD ecosystem and a few fancy array libraries
            """
        )
        write_section(fh, "julia")
        println(fh)

        println(
            fh,
            """
            and some pet projects during my PhD
            """
        )
        write_section(fh, "pets")
        println(fh)

        println(
            fh, 
            """

            ## Acknowledgements
            The script that generates this profile was created by [Frames](https://github.com/oxinabox/oxinabox).
            In her own words: "It's pretty fun little webscrapy markdown generaty thing."
            """
        )
    end

    @info "done"
end

function write_section(fh, section_name)
    @info "gathering data: $section_name"
    repo_urls = CSV.File(joinpath(dirname(@__DIR__), "data", "$section_name.csv")).repo
    infos = map(get_info, repo_urls)  # could use asyncmap but that gives HTTP 429 error (too many requests)
    @info "writing content: $section_name"
    for project_info in infos
        show(fh, MIME("text/markdown"), project_info)
    end
    @info "done: $section_name"
end

Base.@kwdef struct ProjectInfo
    url
    user
    name
    description
    icon
end

read_url(url) = parsehtml(String(take!(download(url, IOBuffer()))))

function get_info(url)
    doc = read_url(url)
    get_only(sel) = only(eachmatch(sel, doc.root))
    user = text(only(eachmatch(sel"[itemprop='author']", doc.root)))

    
    description = get_only(sel"meta[name='description']")."content"
    # strip github's cruft
    description = replace(description, r" - GitHub - .*"=>"")
    description = replace(description, r" Contribute to .*"=>"")
    description = strip(description)

    return ProjectInfo(;
        url,
        user,
        name = text(only(eachmatch(sel"[itemprop='name']", doc.root))),
        description,
        icon = get_avatar_url(user),
    )
end

const _AVATAR_URL_CACHE = Dict{String,String}()
function get_avatar_url(user)
    get!(_AVATAR_URL_CACHE, user) do
        doc = read_url(joinpath("https://github.com", user))
        eles = eachmatch(sel"img[itemprop='image']", doc.root)
        if isempty(eles)  # probably means is personal repo not org repo
            eles = eachmatch(sel"img.avatar-user", doc.root)
        end
        return first(eles)."src"
    end
end


function Base.show(io::IO, ::MIME"text/markdown", info::ProjectInfo)
    print(io, " - ")
    print(io, "<a href='https://github.com/$(info.user)' title='$(info.user)'> <img src='$(info.icon)' height='20' width='20'/></a> ")
    print(io, "[**$(info.user)/$(info.name)**]($(info.url)): ")
    print(io, "_$(info.description)_")
    println(io)
end




main()
