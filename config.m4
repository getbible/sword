dnl SPDX-License-Identifier: GPL-2.0-only

PHP_ARG_ENABLE(
  [getbiblesword],
  [whether to enable getBibleSword support],
  [AS_HELP_STRING(
    [--enable-getbiblesword],
    [Enable native getBibleSword support]
  )],
  [yes]
)

AS_IF([test "$PHP_GETBIBLESWORD" != "no"], [
  AC_PATH_PROG([PKG_CONFIG], [pkg-config], [no])
  AS_IF([test "$PKG_CONFIG" = "no"], [
    AC_MSG_ERROR([pkg-config is required to build getbiblesword])
  ])

  AS_IF(
    [test ! -f "$abs_srcdir/vendor/getbiblesword/src/c_api.cpp"],
    [AC_MSG_ERROR([
      Vendored getBibleSword sources are missing. Use the PIE source package
      or run ./scripts/vendor-dependencies.sh before phpize.
    ])]
  )
  AS_IF(
    [test ! -f "$abs_srcdir/vendor/sword-1.9.0.tar.gz"],
    [AC_MSG_ERROR([
      The verified SWORD 1.9.0 source archive is missing. Use the PIE source
      package or run ./scripts/vendor-dependencies.sh before phpize.
    ])]
  )

  GBS_SWORD_PREFIX="$(pwd)/.getbiblesword/sword-1.9.0"
  AC_MSG_NOTICE([preparing pinned PIC-static SWORD 1.9.0])
  "$abs_srcdir/scripts/build-sword.sh" \
    "$GBS_SWORD_PREFIX" \
    "$abs_srcdir/vendor/sword-1.9.0.tar.gz" \
    || AC_MSG_ERROR([failed to build bundled SWORD 1.9.0])

  GBS_SWORD_PKGCONFIG="$GBS_SWORD_PREFIX/lib/pkgconfig"
  GBS_SWORD_PKGCONFIG_PREFIX="--define-variable=prefix=$GBS_SWORD_PREFIX"
  AS_IF(
    [test ! -f "$GBS_SWORD_PKGCONFIG/sword.pc"],
    [AC_MSG_ERROR([bundled SWORD pkg-config metadata was not installed])]
  )
  AS_IF(
    [! PKG_CONFIG_PATH="$GBS_SWORD_PKGCONFIG${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}" \
      "$PKG_CONFIG" "$GBS_SWORD_PKGCONFIG_PREFIX" \
      --exists "sword = 1.9.0"],
    [AC_MSG_ERROR([bundled SWORD 1.9.0 pkg-config package was not found])]
  )

  GBS_SWORD_CFLAGS="$(
    PKG_CONFIG_PATH="$GBS_SWORD_PKGCONFIG${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}" \
      "$PKG_CONFIG" "$GBS_SWORD_PKGCONFIG_PREFIX" \
      --cflags "sword = 1.9.0"
  )"
  GBS_SWORD_LIBS="$(
    PKG_CONFIG_PATH="$GBS_SWORD_PKGCONFIG${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}" \
      "$PKG_CONFIG" "$GBS_SWORD_PKGCONFIG_PREFIX" \
      --static --libs "sword = 1.9.0"
  )"

  PHP_REQUIRE_CXX()
  CXXFLAGS="$CXXFLAGS -std=c++20 -fvisibility=hidden -fvisibility-inlines-hidden"
  PHP_EVAL_INCLINE($GBS_SWORD_CFLAGS)
  PHP_EVAL_LIBLINE($GBS_SWORD_LIBS, GETBIBLESWORD_SHARED_LIBADD)
  PHP_ADD_LIBRARY([stdc++], [1], [GETBIBLESWORD_SHARED_LIBADD])
  PHP_ADD_LIBRARY([pthread], [1], [GETBIBLESWORD_SHARED_LIBADD])
  GETBIBLESWORD_SHARED_LIBADD="$GETBIBLESWORD_SHARED_LIBADD -Wl,--exclude-libs,ALL"
  PHP_SUBST([GETBIBLESWORD_SHARED_LIBADD])

  PHP_ADD_INCLUDE([$abs_srcdir/vendor/getbiblesword/include])
  PHP_ADD_INCLUDE([$abs_srcdir/vendor/getbiblesword/generated])
  PHP_ADD_INCLUDE([$abs_srcdir/vendor/getbiblesword/src])

  getbiblesword_sources="
    getbiblesword.c
    vendor/getbiblesword/src/annotation.cpp
    vendor/getbiblesword/src/artifact.cpp
    vendor/getbiblesword/src/base64.cpp
    vendor/getbiblesword/src/byte_value.cpp
    vendor/getbiblesword/src/c_api.cpp
    vendor/getbiblesword/src/callback_streambuf.cpp
    vendor/getbiblesword/src/ndjson_writer.cpp
    vendor/getbiblesword/src/sha256.cpp
    vendor/getbiblesword/src/sword_extractor.cpp
  "

  PHP_NEW_EXTENSION(
    [getbiblesword],
    [$getbiblesword_sources],
    [$ext_shared],
    [],
    [-DZEND_ENABLE_STATIC_TSRMLS_CACHE=1 -Wall -Wextra -Werror -Wno-unused-parameter],
    [cxx]
  )
])
