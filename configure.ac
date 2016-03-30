AC_PREREQ(2.61)
AC_INIT([disnixos], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.9 tar-pax -Wall -Werror -Wno-extra-portability])

# Checks for installed programs
AC_DEFUN([NEED_PROG],
[
AC_PATH_PROG($1, $2)
if test -z "$$1"; then
    AC_MSG_ERROR([$2 is required])
fi
])

# Checks for programs
AC_PROG_INSTALL
PKG_PROG_PKG_CONFIG
NEED_PROG(socat, socat)
NEED_PROG(getopt, getopt)
AC_PATH_PROG(xmllint, xmllint, false)
AC_PATH_PROG(xsltproc, xsltproc, false)
AC_PATH_PROG(dblatex, dblatex)
AC_PATH_PROG(HELP2MAN, help2man, false)
AC_PATH_PROG(DOCLIFTER, doclifter, false)

# Checks for Docbook stuff
AC_ARG_WITH(docbook-rng, AC_HELP_STRING([--with-docbook-rng=PATH],
  [path of the DocBook RelaxNG schema]),
  docbookrng=$withval, docbookrng=/docbook-rng-missing)
AC_SUBST(docbookrng)

AC_ARG_WITH(docbook-xsl, AC_HELP_STRING([--with-docbook-xsl=PATH],
  [path of the DocBook XSL stylesheets]),
  docbookxsl=$withval, docbookxsl=/docbook-xsl-missing)
AC_SUBST(docbookxsl)

# Checks for Disnix libraries
DISNIX_REQUIRED=0.4
PKG_CHECK_MODULES(DISNIX, disnix >= $DISNIX_REQUIRED)
DISNIX_PREFIX=`pkg-config --variable=prefix disnix`
AC_SUBST(DISNIX_PREFIX)

# Output
AC_CONFIG_FILES([
Makefile
doc/Makefile
doc/manual/Makefile
scripts/Makefile
data/Makefile
data/generate-infrastructure.nix
data/generate-tests.nix
data/testing.nix
data/instantiate.nix
data/manifest.nix
maintenance/Makefile
scripts/disnix-backdoor-client
scripts/disnix-nixops-client
scripts/disnixos-instantiate
scripts/disnixos-manifest
scripts/disnixos-deploy-network
scripts/disnixos-env
scripts/disnixos-geninfra
scripts/disnixos-gentests
scripts/disnixos-vm-env
scripts/disnixos-collect-garbage
scripts/disnixos-clean-snapshots
scripts/disnixos-query
scripts/disnixos-snapshot-network
scripts/disnixos-restore-network
scripts/disnixos-delete-network-state
])
AC_OUTPUT
