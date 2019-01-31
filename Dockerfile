FROM alpine:edge

# install build packages
RUN \
	apk add --no-cache \
		autoconf \
		automake \
		curl \
		g++ \
		make

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \
		/tmp/par2 \
	&& PAR2_COMMIT=$(curl -sX GET "https://api.github.com/repos/Parchive/par2cmdline/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]') \
	&& curl -o \
	/tmp/par2.tar.gz -L \
	"https://github.com/Parchive/par2cmdline/archive/${PAR2_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/par2.tar.gz -C \
	/tmp/par2 --strip-components=1 \
	&& echo "PAR2_VERSION=${PAR2_COMMIT:0:7}" > /tmp/version.txt
  
# build and archive package
RUN \
	set -ex \
	&& . /tmp/version.txt \
	&& mkdir -p \
		/build \
	&& cd /tmp/par2 \
	&& aclocal \
	&& automake --add-missing \
	&& autoconf \
	&& LDFLAGS="-static" ./configure \
		--prefix=/usr \
	&& make \
	&& make DESTDIR=/tmp/build install \
	&& strip --strip-all /tmp/build/usr/bin/par2 \
	&& tar -czvf /build/par2-${PAR2_VERSION}.tar.gz -C /tmp/build/usr/bin par2

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
