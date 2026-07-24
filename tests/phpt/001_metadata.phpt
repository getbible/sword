--TEST--
getBibleSword metadata and constants
--EXTENSIONS--
getbiblesword
--FILE--
<?php
use GetBible\Sword\Engine;

var_dump(extension_loaded('getbiblesword'));
var_dump(Engine::abiVersion());
var_dump(Engine::productVersion());
var_dump(Engine::contractIdentifier());
var_dump(Engine::ABI_VERSION);
var_dump(Engine::DEFAULT_ARTIFACT_CHUNK_SIZE);
?>
--EXPECT--
bool(true)
int(1)
string(5) "0.3.0"
string(24) "getbiblesword.ndjson/v1"
int(1)
int(1048576)
