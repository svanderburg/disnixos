AC_PREREQ(2.61)
AC_INIT([disnixos], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror -Wno-extra-portability])

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
AC_PATH_PROG(xmllint, xmllint, false)
AC_PATH_PROG(xsltproc, xsltproc, false)
AC_PATH_PROG(dblatex, dblatex)

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
DISNIX_REQUIRED=0.2
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
data/generate-services.nix
data/generate-tests.nix
data/testing.nix
scripts/disnix-backdoor-client
scripts/disnixos-deploy-network
scripts/disnixos-env
scripts/disnixos-geninfra
scripts/disnixos-genservices
scripts/disnixos-gentests
scripts/disnixos-vm-env
])
AC_OUTPUT
