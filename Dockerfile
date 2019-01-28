FROM ubuntu:bionic

# install build packages
RUN \
	apt-get update \
	&& apt-get install -y \
		automake \
		g++ \
		git \
		make

# fetch source code
RUN \
	set -ex \
	&& git clone https://github.com/Parchive/par2cmdline.git /tmp/par2

# build and archive package
RUN \
	set -ex \
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
	&& tar -czvf /build/par2.tar.gz -C /tmp/build/usr/bin par2

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]
