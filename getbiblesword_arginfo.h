/* This is a generated file, edit getbiblesword.stub.php instead.
 * Stub hash: managed by scripts/check-generated.sh
 */

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_GetBible_Sword_Engine___construct, 0, 0, 0)
    ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, modulePath, IS_STRING, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_GetBible_Sword_Engine_abiVersion, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_GetBible_Sword_Engine_productVersion, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_GetBible_Sword_Engine_contractIdentifier arginfo_class_GetBible_Sword_Engine_productVersion
#define arginfo_class_GetBible_Sword_Engine_modulePath arginfo_class_GetBible_Sword_Engine_productVersion

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_GetBible_Sword_Engine_streamModules, 0, 1, IS_LONG, 0)
    ZEND_ARG_INFO(0, destination)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_GetBible_Sword_Engine_streamModule, 0, 2, IS_LONG, 0)
    ZEND_ARG_TYPE_INFO(0, module, IS_STRING, 0)
    ZEND_ARG_INFO(0, destination)
    ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, artifactChunkSize, IS_LONG, 0, "1048576")
ZEND_END_ARG_INFO()

ZEND_METHOD(GetBible_Sword_Engine, __construct);
ZEND_METHOD(GetBible_Sword_Engine, abiVersion);
ZEND_METHOD(GetBible_Sword_Engine, productVersion);
ZEND_METHOD(GetBible_Sword_Engine, contractIdentifier);
ZEND_METHOD(GetBible_Sword_Engine, modulePath);
ZEND_METHOD(GetBible_Sword_Engine, streamModules);
ZEND_METHOD(GetBible_Sword_Engine, streamModule);

static const zend_function_entry class_GetBible_Sword_Engine_methods[] = {
    ZEND_ME(GetBible_Sword_Engine, __construct, arginfo_class_GetBible_Sword_Engine___construct, ZEND_ACC_PUBLIC)
    ZEND_ME(GetBible_Sword_Engine, abiVersion, arginfo_class_GetBible_Sword_Engine_abiVersion, ZEND_ACC_PUBLIC | ZEND_ACC_STATIC)
    ZEND_ME(GetBible_Sword_Engine, productVersion, arginfo_class_GetBible_Sword_Engine_productVersion, ZEND_ACC_PUBLIC | ZEND_ACC_STATIC)
    ZEND_ME(GetBible_Sword_Engine, contractIdentifier, arginfo_class_GetBible_Sword_Engine_contractIdentifier, ZEND_ACC_PUBLIC | ZEND_ACC_STATIC)
    ZEND_ME(GetBible_Sword_Engine, modulePath, arginfo_class_GetBible_Sword_Engine_modulePath, ZEND_ACC_PUBLIC)
    ZEND_ME(GetBible_Sword_Engine, streamModules, arginfo_class_GetBible_Sword_Engine_streamModules, ZEND_ACC_PUBLIC)
    ZEND_ME(GetBible_Sword_Engine, streamModule, arginfo_class_GetBible_Sword_Engine_streamModule, ZEND_ACC_PUBLIC)
    ZEND_FE_END
};
