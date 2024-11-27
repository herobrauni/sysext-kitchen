## How to build

```sh
just setup

IMAGE_REFERENCE="ghcr.io/ublue-os/bazzite"
EXTENSION_NAME="50-example"
just build $IMAGE_REFERENCE $EXTENSION_NAME
```

## How to add/remove packages

See `mkosi.conf.d/10-example.conf`.

## How to add repos

See `mkosi.conf.d/10-dx`.
