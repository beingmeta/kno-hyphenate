KNOCONFIG       ::= knoconfig
prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell ${KNOCONFIG} cflags)
KNO_LDFLAGS	::= -fPIC $(shell ${KNOCONFIG} ldflags)
CFLAGS		::= ${CFLAGS} ${KNO_CFLAGS}
LDFLAGS		::= ${LDFLAGS} ${KNO_LDFLAGS}
DATADIR		::= $(DESTDIR)$(shell ${KNOCONFIG} data)
CMODULES	::= $(DESTDIR)$(shell ${KNOCONFIG} cmodules)
LIBS		::= $(shell ${KNOCONFIG} libs)
LIB		::= $(shell ${KNOCONFIG} lib)
INCLUDE		::= $(shell ${KNOCONFIG} include)
KNO_VERSION	::= $(shell ${KNOCONFIG} version)
KNO_MAJOR	::= $(shell ${KNOCONFIG} major)
KNO_MINOR	::= $(shell ${KNOCONFIG} minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
MOD_NAME	::= hyphenate
MOD_RELEASE     ::= $(shell cat etc/release)
MOD_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${MOD_RELEASE}
APKREPO         ::= $(shell ${KNOCONFIG} apkrepo)

GPGID  = FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO   = $(shell which sudo)

default build: ${MOD_NAME}.${libsuffix}

hyphenate.so: hyphenate.c makefile
	@$(MKSO) $(CFLAGS) -o $@ hyphenate.c
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
hyphenate.dylib: hyphenate.c
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} -o $@ $(DYLIB_FLAGS) \
		hyphenate.c
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: hyphenate.c
	etags -o TAGS hyphenate.c

${CMODULES} ${DATADIR}:
	install -d $@

install: build ${CMODULES} ${DATADIR}
	@${SUDO} ${SYSINSTALL} ${MOD_NAME}.${libsuffix} ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@echo === Installed ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR} to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so
	@echo === Linked ${CMODULES}/${MOD_NAME}.so to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ${SYSINSTALL} hyph_en_US.dic ${DATADIR}
	@echo === Installed ${DATADIR}/hyph_en_US.dic

clean:
	rm -f *.o ${MOD_NAME}/*.o *.${libsuffix}
fresh:
	make clean
	make default

debian: hyphenate.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian hyphenate.c makefile
	cat debian/changelog.base | etc/gitchangelog kno-hyphenate > $@.tmp
	if test ! -f debian/changelog; then 					\
	  mv debian/changelog.tmp debian/changelog; 				\
	elif diff debian/changelog debian/changelog.tmp 2>&1 > /dev/null; then 	\
	  mv debian/changelog.tmp debian/changelog; 				\
	else rm debian/changelog.tmp; fi

dist/debian.built: hyphenate.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

dist/debian.signed: dist/debian.built
	debsign --re-sign -k${GPGID} ../kno-hyphenate_*.changes && \
	touch $@

dist/debian.updated: dist/debian.signed
	dupload -c ./dist/dupload.conf --nomail --to bionic ../kno-hyphenate_*.changes && touch $@

deb debs dpkg dpkgs: dist/debian.signed

debfresh: clean
	rm -rf debian
	make dist/debian.signed

update-apt: dist/debian.updated

debinstall: dist/debian.signed
	sudo dpkg -i ../kno-hyphenate_${MOD_VERSION}*.deb

debclean: clean
	rm -rf ../kno-hyphenate_* ../kno-hyphenate-* debian dist/debian.*

debfresh:
	make debclean
	make dist/debian.built

# Alpine packaging

${APKREPO}/dist/x86_64:
	@install -d $@

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/kno-${MOD_NAME}.tar: staging/alpine
	git archive --prefix=kno-${MOD_NAME}/ -o staging/alpine/kno-${MOD_NAME}.tar HEAD

dist/alpine.done: staging/alpine/APKBUILD makefile \
	staging/alpine/kno-${MOD_NAME}.tar ${APKREPO}/dist/x86_64
	cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum && \
		abuild -P ${APKREPO} && \
		touch ../../$@

alpine: dist/alpine.done

.PHONY: alpine

