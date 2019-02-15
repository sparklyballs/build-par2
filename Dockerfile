ARG ALPINE_VER="3.9"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		curl \
		jq \
		tar
# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \
		/tmp/par2-src \
	&& PAR2_RAW_COMMIT=$(curl -sX GET "https://api.github.com/repos/Parchive/par2cmdline/commits/master" \
		| jq '.sha'| xargs) \
	&& PAR2_COMMIT="${PAR2_RAW_COMMIT:0:7}" \
	&& curl -o \
	/tmp/par2.tar.gz -L \
	"https://github.com/Parchive/par2cmdline/archive/${PAR2_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/par2.tar.gz -C \
	/tmp/par2-src --strip-components=1 \
	&& echo "PAR2_COMMIT=${PAR2_COMMIT}" > /tmp/version.txt

FROM alpine:${ALPINE_VER} as build-stage

############## build stage ##############

# copy artifacts from fetch stage
COPY --from=fetch-stage /tmp/par2-src /tmp/par2-src

# set workdir
WORKDIR /tmp/par2-src

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		autoconf \
		automake \
		g++ \
		make

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

# copy fetch and build artifacts
COPY --from=build-stage /tmp/build /tmp/build
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt

# install strip packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		binutils \
		tar

# set workdir
WORKDIR /tmp/build/usr/bin

# strip and archive package
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/build \
	&& strip --strip-all par2 \
	&& tar -czvf /build/par2-"${PAR2_COMMIT}".tar.gz par2 \
	&& chown 1000:1000 /build/par2-"${PAR2_COMMIT}".tar.gz

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]

# hadolint ignore=SC1091
