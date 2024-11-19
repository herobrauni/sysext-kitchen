MKOSI_COMMIT := "5182007dcefd76c11bb2c5cd28013369c97121d4"
MKOSI_SOURCE := "git+https://github.com/systemd/mkosi.git@" + MKOSI_COMMIT
export SUDOIF := if `id -u` == "0" {""} else {"sudo"}

[private]
default:
    just --list

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

    $mkosi -f clean || :
    ${SUDOIF} $mkosi -f clean
    just clean-root

clean-root:
    #!/usr/bin/bash
    cd $(uv tool dir)/mkosi
    find . -uid 0 -or -gid 0 | xargs -r $SUDOIF rm -vrf

build +PACKAGES:
    #!/usr/bin/bash
    mkosi=$(which mkosi)
    [[ -z $mkosi ]] && exit 1

    PACKAGES=$( printf '%s,' {{PACKAGES}} )
    PACKAGES=${PACKAGES%%,}

    for format in sysext confext; do
        $SUDOIF $mkosi --format $format -f -p $PACKAGES
    done
    [[ -n $SUDOIF ]] && just clean-root