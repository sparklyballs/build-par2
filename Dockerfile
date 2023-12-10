ARG ALPINE_VER="3.19"
FROM alpine:${ALPINE_VER} as fetch-stage

# build arguments
ARG RELEASE

############## fetch stage ##############

# install fetch packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		curl \
		git \
		jq


# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# set workdir
WORKDIR /src/par2

# fetch source
RUN \
	if [ -z ${RELEASE+x} ]; then \
	RELEASE=$(curl -u "${SECRETUSER}:${SECRETPASS}" -sX GET "https://api.github.com/repos/animetosho/par2cmdline-turbo/releases/latest" \
	| jq -r ".tag_name"); \
	fi \
	&& git clone https://github.com/animetosho/par2cmdline-turbo.git /src/par2 \
	&& RELEASE="${RELEASE:0:7}" \
	&& git checkout "${RELEASE}"

FROM alpine:${ALPINE_VER} as build-stage

############## build stage ##############

# copy artifacts from fetch stage
COPY --from=fetch-stage /src /src

# set workdir
WORKDIR /src/par2

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		autoconf \
		automake \
		bash \
		g++ \
		make

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# build package
RUN \
	set -ex \
	&& aclocal \
	&& automake --add-missing \
	&& autoconf \
	&& LDFLAGS="-static" ./configure \
		--prefix=/usr \
	&& make \
	&& make DESTDIR=/tmp/build install

FROM alpine:${ALPINE_VER}

############## package stage ##############

# build arguments
ARG RELEASE

# copy fetch and build artifacts
COPY --from=build-stage /tmp/build /tmp/build

# install strip packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		binutils \
		curl \
		jq \
		tar

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# set workdir
WORKDIR /tmp/build/usr/bin

# strip and archive package
# hadolint ignore=SC1091
RUN \
	if [ -z ${RELEASE+x} ]; then \
	RELEASE=$(curl -u "${SECRETUSER}:${SECRETPASS}" -sX GET "https://api.github.com/repos/animetosho/par2cmdline-turbo/releases/latest" \
	| jq -r ".tag_name"); \
	fi \
	&& RELEASE="${RELEASE:0:7}" \
	&& set -ex \
	&& mkdir -p \
		/build \
	&& strip --strip-all par2 \
	&& tar -czvf /build/par2-"${RELEASE}".tar.gz par2 \
	&& chown -R 1000:1000 /build

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
