MKOSI_COMMIT := "5182007dcefd76c11bb2c5cd28013369c97121d4"
MKOSI_SOURCE := "git+https://github.com/systemd/mkosi.git@" + MKOSI_COMMIT
export SUDOIF := if `id -u` == "0" {""} else {"sudo"}

[private]
default:
    just --list

all: builddeps clean prepare-sandbox build

builddeps:
    #!/usr/bin/bash

    function commandq () {
        command -v $1 >/dev/null
        return
    }

    if ! commandq mkosi; then
        if ! commandq uv; then
            commandq brew || { exit 1; }
            brew install uv
        fi
        uv tool install {{MKOSI_SOURCE}}
    fi

clean:
    #!/usr/bin/bash
    mkosi=$(which mkosi)
    [[ -z $mkosi ]] && exit 1

    $mkosi -f clean
    ${SUDOIF} $mkosi -f clean
    just clean-root

clean-root:
    #!/usr/bin/bash
    pushd $(uv tool dir)/mkosi
    find . -uid 0 -or -gid 0 | xargs -r $SUDOIF rm -vrf
    popd

prepare-sandbox:
    #!/usr/bin/bash
    set -x
    rm -rf mkosi.sandbox/*
    mkdir -p mkosi.sandbox/etc
    pushd mkosi.sandbox/etc
    cp -r /etc/{os-release,yum.repos.d} .
    popd

build:
    #!/usr/bin/bash
    mkosi=$(which mkosi)
    [[ -z $mkosi ]] && exit 1

    $SUDOIF $mkosi -f
    [[ -n $SUDOIF ]] && just clean-root