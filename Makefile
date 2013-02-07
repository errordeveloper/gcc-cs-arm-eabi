SHELL = /bin/bash
TARGET=arm-none-eabi
PROCS=4
CS_BASE = 2010.09
CS_REV = 51
GCC_VERSION = 4.5
MPC_VERSION = 0.8.1
CS_VERSION = $(CS_BASE)-$(CS_REV)
LOCAL_BASE = arm-$(CS_VERSION)-arm-none-eabi
LOCAL_SOURCE = $(LOCAL_BASE).src.tar.bz2
SOURCE_URL = http://www.codesourcery.com/sgpp/lite/arm/portal/package7812/public/arm-none-eabi/$(LOCAL_SOURCE)
MD5_CHECKSUM = 0ab992015a71443efbf3654f33ffc675

PREFIX=/opt/devel/tools/cctc/vendor/cs/arm-$(CS_VERSION)-hugovincent-67f6a93b9f5a5e21abc00cff63f4c09ce312f270

install-cross: cross-binutils cross-gcc cross-g++ cross-newlib cross-gdb
install-deps: gmp mpfr mpc

$(LOCAL_SOURCE):
	curl -LO $(SOURCE_URL)

download: $(LOCAL_SOURCE)
	@(t1=`openssl md5 $(LOCAL_SOURCE) | cut -f 2 -d " " -` && \
	test $$t1 = $(MD5_CHECKSUM) || \
	echo "Bad Checksum! Please remove the following file and retry:\n$(LOCAL_SOURCE)")

$(LOCAL_BASE)/%-$(CS_VERSION).tar.bz2 : download
	@(tgt=`tar -jtf $(LOCAL_SOURCE) | grep  $*` && \
	tar -jxvf $(LOCAL_SOURCE) $$tgt)

gcc-$(GCC_VERSION)-$(CS_BASE) : $(LOCAL_BASE)/gcc-$(CS_VERSION).tar.bz2
	tar -jxf $<

mpc-$(MPC_VERSION) : $(LOCAL_BASE)/mpc-$(CS_VERSION).tar.bz2
	tar -jxf $<


%-$(CS_BASE) : $(LOCAL_BASE)/%-$(CS_VERSION).tar.bz2
	tar -jxf $<

multilibbash: gcc-$(GCC_VERSION)-$(CS_BASE)/
	pushd gcc-$(GCC_VERSION)-$(CS_BASE) ; \
	patch -N -p0 < ../patches/gcc-multilib-bash.patch ; \
	popd ;

gcc-optsize-patch: gcc-$(GCC_VERSION)-$(CS_BASE)/
	pushd gcc-$(GCC_VERSION)-$(CS_BASE) ; \
	patch -N -p1 < ../patches/gcc-optsize.patch ; \
	popd ;

newlibpatch: newlib-$(CS_BASE)/
	pushd newlib-$(CS_BASE) ; \
	patch -N -p1 < ../patches/freertos-newlib.patch ; \
	popd ;

gmp: gmp-$(CS_BASE)/
	mkdir -p build/gmp && cd build/gmp ; \
	pushd ../../gmp-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../gmp-$(CS_BASE)/configure --prefix=$(PREFIX) \
	  --enable-cxx --build=x86_64-apple-darwin --disable-shared && \
	$(MAKE) -j$(PROCS) all && \
	$(MAKE) install

mpc: mpc-$(MPC_VERSION)/
	mkdir -p build/gmp && cd build/gmp ; \
	pushd ../../mpc-$(MPC_VERSION) ; \
	make clean ; \
	popd ; \
	../../mpc-$(MPC_VERSION)/configure --prefix=$(PREFIX) \
	  --with-gmp=$(PREFIX) --with-mpfr=$(PREFIX) --build=x86_64-apple-darwin --disable-shared && \
	$(MAKE) -j$(PROCS) all && \
	$(MAKE) install

mpfr: gmp mpfr-$(CS_BASE)/
	mkdir -p build/mpfr && cd build/mpfr && \
	pushd ../../mpfr-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../mpfr-$(CS_BASE)/configure --prefix=$(PREFIX) \
	  LDFLAGS="-Wl,-search_paths_first" \
	  --with-gmp=$(PREFIX) --build=x86_64-apple-darwin --disable-shared && \
	$(MAKE) -j$(PROCS) all && \
	$(MAKE) install

cross-binutils: binutils-$(CS_BASE)/
	mkdir -p build/binutils && cd build/binutils && \
	pushd ../../binutils-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../binutils-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) --disable-nls --disable-werror && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-host install-target

CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -fomit-frame-pointer \
				  -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -g -Os \
				  -fshort-wchar -fno-unroll-loops -mabi=aapcs -fno-exceptions"
cross-gcc: cross-binutils gcc-$(GCC_VERSION)-$(CS_BASE)/ multilibbash gcc-optsize-patch
	mkdir -p build/gcc && cd build/gcc && \
	pushd ../../gcc-$(GCC_VERSION)-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../gcc-$(GCC_VERSION)-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) \
	--enable-languages="c" --with-gnu-ld --with-gnu-as --with-newlib --disable-nls \
	--disable-libssp --with-newlib --without-headers --disable-shared --enable-target-optspace \
	--disable-threads --disable-libmudflap --disable-libgomp --disable-libstdcxx-pch \
	--disable-libunwind-exceptions --disable-libffi --enable-extra-sgxxlite-multilibs \
	--enable-libstdcxx-allocator=malloc --enable-lto \
	--enable-cxx-flags=$(CFLAGS_FOR_TARGET) \
	--with-gmp=$(PREFIX) --with-mpfr=$(PREFIX) --with-mpc=$(PREFIX) \
	--with-libelf=/opt/brew/Cellar/libelf/0.8.13 \
	CFLAGS_FOR_TARGET=$(CFLAGS_FOR_TARGET) && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-target && \
	$(MAKE) -C gcc install-common install-cpp install- install-driver install-headers install-man

cross-g++: cross-binutils cross-gcc cross-newlib gcc-$(GCC_VERSION)-$(CS_BASE)/ multilibbash gcc-optsize-patch
	mkdir -p build/g++ && cd build/g++ && \
	../../gcc-$(GCC_VERSION)-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) \
	--enable-languages="c++" --with-gnu-ld --with-gnu-as --with-newlib --disable-nls \
	--disable-libssp --with-newlib --without-headers --disable-shared \
	--disable-threads --disable-libmudflap --disable-libgomp --disable-libstdcxx-pch \
	--disable-libunwind-exceptions --disable-libffi --enable-extra-sgxxlite-multilibs \
	--enable-libstdcxx-allocator=malloc --enable-lto \
	--enable-cxx-flags=$(CFLAGS_FOR_TARGET) \
	--with-gmp=$(PREFIX) --with-mpfr=$(PREFIX) --with-mpc=$(PREFIX) \
	--with-libelf=/opt/brew/Cellar/libelf/0.8.13 \
	CFLAGS_FOR_TARGET=$(CFLAGS_FOR_TARGET) && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-target && \
	$(MAKE) -C gcc install-common install-cpp install- install-driver install-headers install-man

NEWLIB_FLAGS="-ffunction-sections -fdata-sections -DPREFER_SIZE_OVER_SPEED \
			 -D__OPTIMIZE_SIZE__ -g -Os -fomit-frame-pointer -fno-unroll-loops \
			 -D__BUFSIZ__=128 -mabi=aapcs -DSMALL_MEMORY -fshort-wchar \
			 -DREENTRANT_SYSCALLS_PROVIDED -D_REENT_ONLY -DSIGNAL_PROVIDED \
			 -DHAVE_NANOSLEEP -DHAVE_FCNTL -DHAVE_RENAME -D_NO_GETLOGIN \
			 -D_NO_GETPWENT -D_NO_GETUT -D_NO_GETPASS -D_NO_SIGSET"
cross-newlib: cross-binutils cross-gcc newlib-$(CS_BASE)/ newlibpatch
	mkdir -p build/newlib && cd build/newlib && \
	pushd ../../newlib-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../newlib-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) \
	--disable-newlib-supplied-syscalls --disable-libgloss --disable-nls \
	--disable-shared --enable-newlib-io-long-long --enable-target-optspace \
	--enable-newlib-multithread --enable-newlib-reent-small \
	--disable-newlib-atexit-alloc --disable-newlib-io-float && \
	$(MAKE) -j$(PROCS) CFLAGS_FOR_TARGET=$(NEWLIB_FLAGS) CCASFLAGS=$(NEWLIB_FLAGS) && \
	$(MAKE) install

cross-gdb: gdb-$(CS_BASE)/
	mkdir -p build/gdb && cd build/gdb && \
	pushd ../../gdb-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../gdb-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) --disable-werror && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-host install-target && \
	mkdir -p $(PREFIX)/man/man1 && \
	cp ../../gdb-$(CS_BASE)/gdb/gdb.1 $(PREFIX)/man/man1/arm-none-eabi-gdb.1

.PHONY : clean
clean:
	rm -rf build *-$(CS_BASE) binutils-* gcc-* gdb-* newlib-* mpc-* $(LOCAL_BASE)
