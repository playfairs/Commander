build_dir := "build"
version := "{{git_tag}}"

build-clean:
    rm -rf {{build_dir}}

checks:
    swift --version
    swift package resolve
    swift build -c release
    swift test

package: build-clean
    ./scripts/build_app.sh {{version}} {{build_dir}}
    ./scripts/create_pkg.sh {{version}} {{build_dir}}
    ./scripts/create_dmg.sh {{version}} {{build_dir}}

ci-publish-macos: checks
    just package

