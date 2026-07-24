--TEST--
Engine public surface is stable and typed
--EXTENSIONS--
getbiblesword
--FILE--
<?php
$class = new ReflectionClass(GetBible\Sword\Engine::class);
echo $class->isFinal() ? "final\n" : "not-final\n";

foreach ([
    '__construct',
    'abiVersion',
    'productVersion',
    'contractIdentifier',
    'modulePath',
    'streamModules',
    'streamModule',
] as $name) {
    $method = $class->getMethod($name);
    printf(
        "%s:%s:%d:%s\n",
        $name,
        $method->isStatic() ? 'static' : 'instance',
        $method->getNumberOfRequiredParameters(),
        $method->hasReturnType() ? (string) $method->getReturnType() : 'none'
    );
}
?>
--EXPECT--
final
__construct:instance:0:none
abiVersion:static:0:int
productVersion:static:0:string
contractIdentifier:static:0:string
modulePath:instance:0:string
streamModules:instance:1:int
streamModule:instance:2:int
