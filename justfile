build_dir := "build"
version := "{{git_tag}}"

build-clean:
    rm -rf {{build_dir}}

checks:
    swift --version
    swift package resolve
    swift build -c release
    swift test