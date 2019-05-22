#!/bin/bash -e
#
# Build static rtty inside minimal Alpine-Linux docker image
#
# To extract the built artifact from the image:
#   docker run --rm rtty:TAG > rtty && chmod +x rtty
#
alpine_tag=3.9
this_image=rtty:alpine-${alpine_tag}

here="$(readlink -f $(dirname $0))"
dest="/app/local"

docker_build() {
  local tag="$1"; shift

  # Remember the given tag's Image-ID for removal
  local old_id="$(docker images --format '{{.ID}}' ${tag})"

  docker build --force-rm --network=host -t "${tag}" "$@"

  local new_id="$(docker images --format '{{.ID}}' ${tag})"

  # ID does not change if the build is exactly the same as before
  [ -n "${old_id}" -a "${old_id}" != "${new_id}" ] \
    && docker rmi "${old_id}" >/dev/null
}

docker_build ${this_image} -f - ${here} <<DOCKER_FILE
FROM alpine:${alpine_tag}

COPY ./ /src/

RUN /src/apk-builder.sh add && \
    /src/build.sh -static && \
    mkdir -p ${dest} && \
    strip -o ${dest}/rtty /src/scratch/usr/local/bin/rtty && \
    /src/apk-builder.sh del && \
    rm -rf /src /usr/bin/openssl && \
    >&2 ls -l ${dest}/rtty

CMD ["/bin/cat", "${dest}/rtty"]
DOCKER_FILE
