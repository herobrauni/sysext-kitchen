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

    mkosi -f clean || :
    ${SUDOIF} mkosi -f clean || :
    ${SUDOIF} rm -rf mkosi.{output,cache}/*

build $IMAGE_REF="ghcr.io/ublue-os/bazzite" $IMAGE_NAME="":
    #!/usr/bin/bash
    set -xeuo pipefail
    [[ -z $IMAGE_NAME || -z $IMAGE_REF ]] && {
      echo >&2 "IMAGE_REF and IMAGE_REF must NOT be empty."
      exit 1
    }
    just prepare-overlay-tar $IMAGE_REF
    for format in sysext confext; do
      {
      mkosi -f \
        --format $format \
        --output $IMAGE_NAME.$format
      } >&2
      realpath $IMAGE_NAME.$format
    done

prepare-overlay-tar $IMAGE_REF:
    #!/usr/bin/bash

    set -xe
    : ${IMAGE_REF?ERROR: missing container image reference}
    DESTDIR=mkosi.basetree.tar
    APPEND_SELINUX=1
    TMP_SELINUX_TAR=.tmp_selinux.tar

    container=$(buildah from $IMAGE_REF)

    buildah run $container -- /usr/bin/bash --norc --noprofile <<-EOF 
      #!/usr/bin/bash
      set -xe
      touch -c /usr/lib/os-release
      #### Here we make the changes we want to apply to our system extension ####

      dnf5 -y install hello 
      dnf5 -y clean all

    EOF

    image=$(buildah commit $container output)

    upperdir=$(podman inspect $image | jq -r '.[].GraphDriver.Data.UpperDir')

    (cd $upperdir && tar -c . -f -) >$DESTDIR

    # Append selinux context
    if (( APPEND_SELINUX )); then
      buildah run $container tar -C / -cf - etc/selinux > $TMP_SELINUX_TAR
      tar -f $DESTDIR --concatenate $TMP_SELINUX_TAR
      rm $TMP_SELINUX_TAR
    fi

    buildah rm $container
    podman rmi $image
