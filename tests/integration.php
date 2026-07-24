<?php

declare(strict_types=1);

use GetBible\Sword\Engine;
use GetBible\Sword\Exception;

if ($argc !== 4) {
    fwrite(STDERR, "Usage: php integration.php SWORD_ROOT LIST_OUTPUT EXTRACT_OUTPUT\n");
    exit(2);
}

[$script, $swordRoot, $listOutput, $extractOutput] = $argv;
unset($script);

function assertTrue(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function streamToFile(callable $operation, string $path): int
{
    $stream = fopen($path, 'wb');
    if ($stream === false) {
        throw new RuntimeException("Unable to open test output: {$path}");
    }

    try {
        return $operation($stream);
    } finally {
        fclose($stream);
    }
}

$engine = new Engine($swordRoot);
assertTrue($engine->modulePath() === $swordRoot, 'Explicit module path changed.');
assertTrue(Engine::abiVersion() === 1, 'Unexpected ABI version.');
assertTrue(Engine::productVersion() === '0.3.0', 'Unexpected engine version.');
assertTrue(
    Engine::contractIdentifier() === 'getbiblesword.ndjson/v1',
    'Unexpected contract identifier.'
);

$listBytes = streamToFile(
    static fn ($stream): int => $engine->streamModules($stream),
    $listOutput
);
$list = file_get_contents($listOutput);
assertTrue($list !== false, 'Unable to read list output.');
assertTrue(strlen($list) === $listBytes, 'List byte count differs.');
assertTrue(str_contains($list, '"utf8":"PhpFixture"'), 'Fixture module not listed.');
assertTrue(str_contains($list, '"success":true'), 'List footer is not successful.');

$extractBytes = streamToFile(
    static fn ($stream): int => $engine->streamModule(
        'PhpFixture',
        $stream,
        Engine::MINIMUM_ARTIFACT_CHUNK_SIZE
    ),
    $extractOutput
);
$extract = file_get_contents($extractOutput);
assertTrue($extract !== false, 'Unable to read extraction output.');
assertTrue(strlen($extract) === $extractBytes, 'Extraction byte count differs.');
assertTrue(str_contains($extract, '"type":"entry"'), 'No entry records emitted.');
assertTrue(str_contains($extract, '"success":true'), 'Extraction footer is not successful.');

$failedStream = fopen('php://temp', 'w+b');
assertTrue(is_resource($failedStream), 'Unable to create failed-operation stream.');
try {
    $engine->streamModule('MissingModule', $failedStream);
    throw new RuntimeException('Missing module did not throw.');
} catch (Exception $exception) {
    assertTrue(
        $exception->getCode() === 2,
        'Missing module did not return extraction-failed status.'
    );
}
rewind($failedStream);
$failedOutput = stream_get_contents($failedStream);
fclose($failedStream);
assertTrue(
    is_string($failedOutput) && str_contains($failedOutput, '"success":false'),
    'Failed extraction did not preserve its NDJSON failure footer.'
);

fwrite(STDOUT, "PHP integration checks passed.\n");
