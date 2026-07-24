/* SPDX-License-Identifier: GPL-2.0-only */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "php.h"
#include "Zend/zend_exceptions.h"
#include "ext/spl/spl_exceptions.h"
#include "ext/standard/info.h"
#include "main/php_streams.h"
#include "php_getbiblesword.h"
#include "getbiblesword_arginfo.h"

#include <getbiblesword/c_api.h>

#include <errno.h>
#include <pwd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define GBS_PASSWD_BUFFER_DEFAULT 16384U
#define GBS_PASSWD_BUFFER_MAXIMUM (1024U * 1024U)

typedef struct php_gbs_engine_object {
    zend_string *module_path;
    zend_object std;
} php_gbs_engine_object;

typedef struct php_gbs_stream_context {
    php_stream *stream;
    uint64_t bytes_written;
} php_gbs_stream_context;

static zend_class_entry *php_gbs_engine_ce;
static zend_class_entry *php_gbs_exception_ce;
static zend_object_handlers php_gbs_engine_handlers;

PHP_INI_BEGIN()
    PHP_INI_ENTRY(
        "getbiblesword.module_path",
        "",
        PHP_INI_SYSTEM | PHP_INI_PERDIR,
        NULL
    )
PHP_INI_END()

static inline php_gbs_engine_object *php_gbs_engine_from_object(
    zend_object *object
) {
    return (php_gbs_engine_object *)(
        (char *)object - XtOffsetOf(php_gbs_engine_object, std)
    );
}

#define Z_GBS_ENGINE_P(zval_pointer) \
    php_gbs_engine_from_object(Z_OBJ_P((zval_pointer)))

static zend_object *php_gbs_engine_create(zend_class_entry *class_entry)
{
    php_gbs_engine_object *object = zend_object_alloc(
        sizeof(php_gbs_engine_object),
        class_entry
    );

    zend_object_std_init(&object->std, class_entry);
    object_properties_init(&object->std, class_entry);
    object->module_path = NULL;
    object->std.handlers = &php_gbs_engine_handlers;

    return &object->std;
}

static void php_gbs_engine_free(zend_object *zend_object)
{
    php_gbs_engine_object *object = php_gbs_engine_from_object(zend_object);

    if (object->module_path != NULL) {
        zend_string_release(object->module_path);
        object->module_path = NULL;
    }

    zend_object_std_dtor(&object->std);
}

static zend_string *php_gbs_path_from_home(const char *home)
{
    const size_t length = strlen(home);

    if (length == 0U) {
        return NULL;
    }
    if (home[length - 1U] == '/') {
        return strpprintf(0, "%s.sword", home);
    }
    return strpprintf(0, "%s/.sword", home);
}

static zend_string *php_gbs_effective_user_home(void)
{
    const char *environment_home = getenv("HOME");
    struct passwd account;
    struct passwd *result = NULL;
    char *buffer;
    long suggested_size;
    size_t buffer_size;
    int status;
    zend_string *path;

    if (environment_home != NULL && environment_home[0] != '\0') {
        return php_gbs_path_from_home(environment_home);
    }

    suggested_size = sysconf(_SC_GETPW_R_SIZE_MAX);
    if (suggested_size <= 0L
        || (unsigned long)suggested_size > GBS_PASSWD_BUFFER_MAXIMUM) {
        buffer_size = GBS_PASSWD_BUFFER_DEFAULT;
    } else {
        buffer_size = (size_t)suggested_size;
    }

    buffer = emalloc(buffer_size);
    status = getpwuid_r(
        geteuid(),
        &account,
        buffer,
        buffer_size,
        &result
    );
    if (status != 0 || result == NULL
        || result->pw_dir == NULL || result->pw_dir[0] == '\0') {
        efree(buffer);
        return NULL;
    }

    path = php_gbs_path_from_home(result->pw_dir);
    efree(buffer);
    return path;
}

static zend_string *php_gbs_resolve_module_path(zend_string *explicit_path)
{
    const char *configured_path;
    const char *environment_path;

    if (explicit_path != NULL) {
        if (ZSTR_LEN(explicit_path) == 0U) {
            zend_argument_value_error(1, "must not be empty");
            return NULL;
        }
        return zend_string_copy(explicit_path);
    }

    configured_path = INI_STR("getbiblesword.module_path");
    if (configured_path != NULL && configured_path[0] != '\0') {
        return zend_string_init(
            configured_path,
            strlen(configured_path),
            0
        );
    }

    environment_path = getenv("SWORD_PATH");
    if (environment_path != NULL && environment_path[0] != '\0') {
        return zend_string_init(
            environment_path,
            strlen(environment_path),
            0
        );
    }

    return php_gbs_effective_user_home();
}

static php_gbs_engine_object *php_gbs_initialized_engine(zval *value)
{
    php_gbs_engine_object *object = Z_GBS_ENGINE_P(value);

    if (object->module_path == NULL) {
        zend_throw_error(
            NULL,
            "GetBible\\Sword\\Engine::__construct() must be called before use"
        );
        return NULL;
    }
    return object;
}

static php_stream *php_gbs_destination_stream(
    zval *destination,
    uint32_t argument_number
) {
    php_stream *stream;

    if (Z_TYPE_P(destination) != IS_RESOURCE) {
        zend_argument_type_error(
            argument_number,
            "must be a writable stream resource"
        );
        return NULL;
    }

    stream = (php_stream *)zend_fetch_resource2_ex(
        destination,
        NULL,
        php_file_le_stream(),
        php_file_le_pstream()
    );
    if (stream == NULL) {
        zend_argument_type_error(
            argument_number,
            "must be a writable stream resource"
        );
        return NULL;
    }

    return stream;
}

static gbs_write_result php_gbs_write_stream(
    const uint8_t *data,
    size_t size,
    void *opaque_context
) {
    php_gbs_stream_context *context = opaque_context;
    size_t offset = 0U;

    while (offset < size) {
        const ssize_t written = php_stream_write(
            context->stream,
            (const char *)data + offset,
            size - offset
        );

        if (written <= 0) {
            return GBS_WRITE_ERROR;
        }
        if (UINT64_MAX - context->bytes_written < (uint64_t)written) {
            return GBS_WRITE_ERROR;
        }

        context->bytes_written += (uint64_t)written;
        offset += (size_t)written;
    }

    return GBS_WRITE_CONTINUE;
}

static void php_gbs_throw_status(gbs_status status, const gbs_error *error)
{
    const char *message = NULL;

    if (error != NULL && error->message[0] != '\0') {
        message = error->message;
    }
    if (message == NULL) {
        message = gbs_status_message(status);
    }

    zend_throw_exception(php_gbs_exception_ce, message, status);
}

static void php_gbs_return_byte_count(
    zval *return_value,
    const php_gbs_stream_context *context
) {
    if (context->bytes_written > (uint64_t)ZEND_LONG_MAX) {
        zend_throw_exception(
            php_gbs_exception_ce,
            "The streamed byte count exceeds PHP's integer range",
            GBS_STATUS_INTERNAL_ERROR
        );
        return;
    }

    ZVAL_LONG(return_value, (zend_long)context->bytes_written);
}

ZEND_METHOD(GetBible_Sword_Engine, __construct)
{
    zend_string *requested_path = NULL;
    zend_string *resolved_path;
    php_gbs_engine_object *object;

    ZEND_PARSE_PARAMETERS_START(0, 1)
        Z_PARAM_OPTIONAL
        Z_PARAM_STR_OR_NULL(requested_path)
    ZEND_PARSE_PARAMETERS_END();

    resolved_path = php_gbs_resolve_module_path(requested_path);
    if (resolved_path == NULL) {
        if (EG(exception) == NULL) {
            zend_throw_exception(
                php_gbs_exception_ce,
                "Unable to resolve a SWORD module path; configure "
                "getbiblesword.module_path, SWORD_PATH, or the effective "
                "user's home directory",
                GBS_STATUS_INVALID_ARGUMENT
            );
        }
        RETURN_THROWS();
    }

    object = Z_GBS_ENGINE_P(ZEND_THIS);
    if (object->module_path != NULL) {
        zend_string_release(object->module_path);
    }
    object->module_path = resolved_path;
}

ZEND_METHOD(GetBible_Sword_Engine, abiVersion)
{
    ZEND_PARSE_PARAMETERS_NONE();
    RETURN_LONG((zend_long)gbs_abi_version());
}

ZEND_METHOD(GetBible_Sword_Engine, productVersion)
{
    const char *version;

    ZEND_PARSE_PARAMETERS_NONE();
    version = gbs_product_version();
    RETURN_STRING(version != NULL ? version : "");
}

ZEND_METHOD(GetBible_Sword_Engine, contractIdentifier)
{
    const char *identifier;

    ZEND_PARSE_PARAMETERS_NONE();
    identifier = gbs_contract_identifier();
    RETURN_STRING(identifier != NULL ? identifier : "");
}

ZEND_METHOD(GetBible_Sword_Engine, modulePath)
{
    php_gbs_engine_object *object;

    ZEND_PARSE_PARAMETERS_NONE();
    object = php_gbs_initialized_engine(ZEND_THIS);
    if (object == NULL) {
        RETURN_THROWS();
    }
    RETURN_STR_COPY(object->module_path);
}

ZEND_METHOD(GetBible_Sword_Engine, streamModules)
{
    zval *destination;
    php_stream *stream;
    php_gbs_engine_object *object;
    php_gbs_stream_context context;
    gbs_error error = GBS_ERROR_INITIALIZER;
    gbs_status status;

    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_ZVAL(destination)
    ZEND_PARSE_PARAMETERS_END();

    object = php_gbs_initialized_engine(ZEND_THIS);
    if (object == NULL) {
        RETURN_THROWS();
    }
    stream = php_gbs_destination_stream(destination, 1U);
    if (stream == NULL) {
        RETURN_THROWS();
    }

    context.stream = stream;
    context.bytes_written = 0U;
    status = gbs_list_modules_v1(
        ZSTR_VAL(object->module_path),
        php_gbs_write_stream,
        &context,
        &error
    );
    if (status != GBS_STATUS_OK) {
        php_gbs_throw_status(status, &error);
        RETURN_THROWS();
    }

    php_gbs_return_byte_count(return_value, &context);
}

ZEND_METHOD(GetBible_Sword_Engine, streamModule)
{
    zend_string *module;
    zval *destination;
    zend_long chunk_size = GBS_DEFAULT_ARTIFACT_CHUNK_SIZE;
    php_stream *stream;
    php_gbs_engine_object *object;
    php_gbs_stream_context context;
    gbs_extract_options_v1 options = GBS_EXTRACT_OPTIONS_V1_INITIALIZER;
    gbs_error error = GBS_ERROR_INITIALIZER;
    gbs_status status;

    ZEND_PARSE_PARAMETERS_START(2, 3)
        Z_PARAM_STR(module)
        Z_PARAM_ZVAL(destination)
        Z_PARAM_OPTIONAL
        Z_PARAM_LONG(chunk_size)
    ZEND_PARSE_PARAMETERS_END();

    if (ZSTR_LEN(module) == 0U) {
        zend_argument_value_error(1, "must not be empty");
        RETURN_THROWS();
    }
    if (chunk_size < (zend_long)GBS_MINIMUM_ARTIFACT_CHUNK_SIZE
        || chunk_size > (zend_long)GBS_MAXIMUM_ARTIFACT_CHUNK_SIZE) {
        zend_argument_value_error(
            3,
            "must be between %u and %u bytes",
            GBS_MINIMUM_ARTIFACT_CHUNK_SIZE,
            GBS_MAXIMUM_ARTIFACT_CHUNK_SIZE
        );
        RETURN_THROWS();
    }

    object = php_gbs_initialized_engine(ZEND_THIS);
    if (object == NULL) {
        RETURN_THROWS();
    }
    stream = php_gbs_destination_stream(destination, 2U);
    if (stream == NULL) {
        RETURN_THROWS();
    }

    options.sword_path = ZSTR_VAL(object->module_path);
    options.module_name = ZSTR_VAL(module);
    options.artifact_chunk_size = (size_t)chunk_size;
    context.stream = stream;
    context.bytes_written = 0U;

    status = gbs_extract_module_v1(
        &options,
        php_gbs_write_stream,
        &context,
        &error
    );
    if (status != GBS_STATUS_OK) {
        php_gbs_throw_status(status, &error);
        RETURN_THROWS();
    }

    php_gbs_return_byte_count(return_value, &context);
}

PHP_MINIT_FUNCTION(getbiblesword)
{
    zend_class_entry class_entry;

    if (gbs_abi_version() != GBS_ABI_VERSION) {
        php_error_docref(
            NULL,
            E_CORE_ERROR,
            "getBibleSword ABI mismatch: extension expects %u, engine provides %u",
            GBS_ABI_VERSION,
            gbs_abi_version()
        );
        return FAILURE;
    }

    REGISTER_INI_ENTRIES();

    INIT_NS_CLASS_ENTRY(
        class_entry,
        "GetBible\\Sword",
        "Exception",
        NULL
    );
    php_gbs_exception_ce = zend_register_internal_class_ex(
        &class_entry,
        spl_ce_RuntimeException
    );

    INIT_NS_CLASS_ENTRY(
        class_entry,
        "GetBible\\Sword",
        "Engine",
        class_GetBible_Sword_Engine_methods
    );
    php_gbs_engine_ce = zend_register_internal_class(&class_entry);
    php_gbs_engine_ce->create_object = php_gbs_engine_create;
    php_gbs_engine_ce->ce_flags |= ZEND_ACC_FINAL
        | ZEND_ACC_NO_DYNAMIC_PROPERTIES
        | ZEND_ACC_NOT_SERIALIZABLE;

    memcpy(
        &php_gbs_engine_handlers,
        &std_object_handlers,
        sizeof(zend_object_handlers)
    );
    php_gbs_engine_handlers.offset = XtOffsetOf(
        php_gbs_engine_object,
        std
    );
    php_gbs_engine_handlers.free_obj = php_gbs_engine_free;
    php_gbs_engine_handlers.clone_obj = NULL;

    zend_declare_class_constant_long(
        php_gbs_engine_ce,
        ZEND_STRL("ABI_VERSION"),
        GBS_ABI_VERSION
    );
    zend_declare_class_constant_long(
        php_gbs_engine_ce,
        ZEND_STRL("DEFAULT_ARTIFACT_CHUNK_SIZE"),
        GBS_DEFAULT_ARTIFACT_CHUNK_SIZE
    );
    zend_declare_class_constant_long(
        php_gbs_engine_ce,
        ZEND_STRL("MINIMUM_ARTIFACT_CHUNK_SIZE"),
        GBS_MINIMUM_ARTIFACT_CHUNK_SIZE
    );
    zend_declare_class_constant_long(
        php_gbs_engine_ce,
        ZEND_STRL("MAXIMUM_ARTIFACT_CHUNK_SIZE"),
        GBS_MAXIMUM_ARTIFACT_CHUNK_SIZE
    );

    return SUCCESS;
}

PHP_MSHUTDOWN_FUNCTION(getbiblesword)
{
    UNREGISTER_INI_ENTRIES();
    return SUCCESS;
}

PHP_MINFO_FUNCTION(getbiblesword)
{
    php_info_print_table_start();
    php_info_print_table_header(2, "getBibleSword support", "enabled");
    php_info_print_table_row(2, "Extension version", PHP_GETBIBLESWORD_VERSION);
    php_info_print_table_row(2, "Engine version", gbs_product_version());
    php_info_print_table_row(2, "C ABI version", "1");
    php_info_print_table_row(2, "NDJSON contract", gbs_contract_identifier());
    php_info_print_table_end();

    DISPLAY_INI_ENTRIES();
}

zend_module_entry getbiblesword_module_entry = {
    STANDARD_MODULE_HEADER,
    PHP_GETBIBLESWORD_EXTNAME,
    NULL,
    PHP_MINIT(getbiblesword),
    PHP_MSHUTDOWN(getbiblesword),
    NULL,
    NULL,
    PHP_MINFO(getbiblesword),
    PHP_GETBIBLESWORD_VERSION,
    STANDARD_MODULE_PROPERTIES
};

#ifdef COMPILE_DL_GETBIBLESWORD
#if defined(ZTS)
ZEND_TSRMLS_CACHE_DEFINE()
#endif
ZEND_GET_MODULE(getbiblesword)
#endif
