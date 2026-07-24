--TEST--
Engine resolves explicit, SWORD_PATH, and HOME module paths
--EXTENSIONS--
getbiblesword
--ENV--
SWORD_PATH=/tmp/getbiblesword-sword-path
HOME=/tmp/getbiblesword-home
--FILE--
<?php
use GetBible\Sword\Engine;

var_dump((new Engine('/explicit/modules'))->modulePath());
var_dump((new Engine())->modulePath());
putenv('SWORD_PATH');
var_dump((new Engine())->modulePath());
?>
--EXPECT--
string(17) "/explicit/modules"
string(29) "/tmp/getbiblesword-sword-path"
string(30) "/tmp/getbiblesword-home/.sword"
