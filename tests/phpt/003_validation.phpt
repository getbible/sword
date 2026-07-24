--TEST--
Engine validates module names, destinations, and chunk sizes
--EXTENSIONS--
getbiblesword
--FILE--
<?php
use GetBible\Sword\Engine;

$engine = new Engine('/tmp');

foreach ([
    static fn () => new Engine(''),
    static fn () => $engine->streamModules('not-a-stream'),
    static fn () => $engine->streamModule('', fopen('php://temp', 'w+b')),
    static fn () => $engine->streamModule('KJV', fopen('php://temp', 'w+b'), 1),
] as $operation) {
    try {
        $operation();
        echo "missing exception\n";
    } catch (ValueError | TypeError $exception) {
        echo $exception::class, "\n";
    }
}
?>
--EXPECT--
ValueError
TypeError
ValueError
ValueError
