AC_PREREQ(2.61)
AC_INIT([disnix-vm-addons], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.7.2 -Wall -Werror])

# Checks for installed programs
AC_DEFUN([NEED_PROG],
[
AC_PATH_PROG($1, $2)
if test -z "$$1"; then
    AC_MSG_ERROR([$2 is required])
fi
])

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
NEED_PROG(socat, socat)

# Output
AC_CONFIG_FILES([
Makefile
scripts/Makefile
data/Makefile
scripts/disnix-backdoor-client
scripts/disnix-generate-infra
scripts/disnix-generate-vms
])
AC_OUTPUT
