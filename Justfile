MKOSI_COMMIT := "5182007dcefd76c11bb2c5cd28013369c97121d4"
MKOSI_SOURCE := "git+https://github.com/systemd/mkosi.git@" + MKOSI_COMMIT
export SUDOIF := if `id -u` == "0" { "" } else { "sudo" }

[private]
default:
    just --list

all: builddeps clean build

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
        uv tool install {{ MKOSI_SOURCE }}
    fi

clean:
    #!/usr/bin/bash

    mkosi clean
    ${SUDOIF} rm -rf mkosi.{output,cache}/*

build $IMAGE_REF="ghcr.io/ublue-os/bazzite" $IMAGE_NAME="":
    #!/usr/bin/bash
    set ${DEBUG:+-x} -euo pipefail
    [[ -z $IMAGE_NAME || -z $IMAGE_REF ]] && {
      echo >&2 "IMAGE_REF and IMAGE_NAME must NOT be empty."
      exit 1
    }
    just prepare-overlay-tar $IMAGE_REF >&2
    for format in sysext confext; do
      {
      ${CI:+sudo} $(which mkosi) \
        --profile $format \
        --output ${IMAGE_NAME}_${format}
      } >&2
      realpath ${IMAGE_NAME}_${format}
    done

prepare-overlay-tar $IMAGE_REF:
    #!/usr/bin/bash

    set -e ${DEBUG:+-x}
    : ${IMAGE_REF?ERROR: missing container image reference}
    TAR_PATH=mkosi.basetree.tar
    if [[ -e $TAR_PATH ]]; then
        echo >&2 "${TAR_PATH} already exists. Skipping..."
        exit 0
    fi

    echo >&2 "Preparing '$(basename $TAR_PATH)'..."

    container=$(podman create $IMAGE_REF)
    trap "podman rm $container" EXIT
    podman cp ${container}:/ - > $TAR_PATH
