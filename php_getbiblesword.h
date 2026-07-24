/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef PHP_GETBIBLESWORD_H
#define PHP_GETBIBLESWORD_H

#include "php.h"

extern zend_module_entry getbiblesword_module_entry;
#define phpext_getbiblesword_ptr &getbiblesword_module_entry

#define PHP_GETBIBLESWORD_EXTNAME "getbiblesword"
#define PHP_GETBIBLESWORD_VERSION "@version@"

#if defined(ZTS) && defined(COMPILE_DL_GETBIBLESWORD)
ZEND_TSRMLS_CACHE_EXTERN()
#endif

#endif
