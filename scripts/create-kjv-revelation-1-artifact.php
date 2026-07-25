<?php

declare(strict_types=1);

use GetBible\Sword\Engine;

const MODULE = 'KJV';
const CANONICAL_BOOK_NUMBER = 66;
const TESTAMENT_NUMBER = 2;
const TESTAMENT_BOOK_NUMBER = 27;
const BOOK_NAME = 'Revelation';
const CHAPTER_NUMBER = 1;
const EXPECTED_VERSES = 20;
const SOURCE_URL = 'https://crosswire.org/ftpmirror/pub/sword/packages/rawzip/KJV.zip';

if ($argc !== 4) {
    fwrite(
        STDERR,
        "Usage: php create-kjv-revelation-1-artifact.php "
        . "SWORD_ROOT OUTPUT_DIRECTORY SOURCE_SHA256\n"
    );
    exit(2);
}

[$script, $swordRoot, $outputDirectory, $sourceSha256] = $argv;
unset($script);

if (!extension_loaded('getbiblesword')) {
    throw new RuntimeException('The getbiblesword extension is not loaded.');
}
if (!preg_match('/^[0-9a-f]{64}$/', $sourceSha256)) {
    throw new InvalidArgumentException('SOURCE_SHA256 must be lowercase SHA-256.');
}
if (!is_dir($outputDirectory) && !mkdir($outputDirectory, 0777, true)) {
    throw new RuntimeException("Unable to create output directory: {$outputDirectory}");
}

$fullStreamPath = tempnam(sys_get_temp_dir(), 'gbs-kjv-');
if ($fullStreamPath === false) {
    throw new RuntimeException('Unable to create the temporary extraction file.');
}

$entryPath = $outputDirectory . '/kjv-revelation-1.entries.ndjson';
$textPath = $outputDirectory . '/kjv-revelation-1.txt';
$manifestPath = $outputDirectory . '/kjv-revelation-1.manifest.json';

/**
 * @return array<string, mixed>
 */
function decodeRecord(string $line, int $lineNumber): array
{
    try {
        $record = json_decode($line, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        throw new RuntimeException(
            "Invalid NDJSON on line {$lineNumber}: {$exception->getMessage()}",
            previous: $exception
        );
    }

    if (!is_array($record)) {
        throw new RuntimeException("NDJSON line {$lineNumber} is not an object.");
    }

    return $record;
}

/**
 * @param array<string, mixed> $value
 */
function utf8Value(array $value, string $field): string
{
    $text = $value['utf8'] ?? null;
    if (!is_string($text)) {
        throw new RuntimeException("The {$field} byte value has no UTF-8 projection.");
    }

    return $text;
}

function openOutput(string $path)
{
    $stream = fopen($path, 'wb');
    if ($stream === false) {
        throw new RuntimeException("Unable to open output file: {$path}");
    }

    return $stream;
}

try {
    $engine = new Engine($swordRoot);
    $fullStream = openOutput($fullStreamPath);
    try {
        $engine->streamModule(MODULE, $fullStream);
    } finally {
        fclose($fullStream);
    }

    $input = fopen($fullStreamPath, 'rb');
    if ($input === false) {
        throw new RuntimeException('Unable to reopen the complete KJV extraction.');
    }
    $entries = openOutput($entryPath);
    $text = openOutput($textPath);

    $verses = [];
    $lineNumber = 0;
    try {
        while (($line = fgets($input)) !== false) {
            ++$lineNumber;
            if (!str_ends_with($line, "\n")) {
                throw new RuntimeException(
                    "NDJSON line {$lineNumber} is not LF-terminated."
                );
            }

            $record = decodeRecord($line, $lineNumber);
            if (($record['type'] ?? null) !== 'entry') {
                continue;
            }

            $scope = $record['scope'] ?? null;
            if (!is_array($scope)
                || ($scope['type'] ?? null) !== 'verse_key'
                || ($scope['intro_scope'] ?? null) !== 'verse'
                || ($scope['testament'] ?? null) !== TESTAMENT_NUMBER
                || ($scope['book'] ?? null) !== TESTAMENT_BOOK_NUMBER
                || ($scope['chapter'] ?? null) !== CHAPTER_NUMBER) {
                continue;
            }

            $verse = $scope['verse'] ?? null;
            if (!is_int($verse) || $verse < 1 || $verse > EXPECTED_VERSES) {
                throw new RuntimeException('Unexpected Revelation 1 verse number.');
            }
            if (isset($verses[$verse])) {
                throw new RuntimeException("Duplicate Revelation 1:{$verse} entry.");
            }

            $osis = utf8Value($scope['osis_reference'] ?? [], 'OSIS reference');
            $expectedOsis = "Rev.1.{$verse}";
            if ($osis !== $expectedOsis) {
                throw new RuntimeException(
                    "Expected {$expectedOsis}, received {$osis}."
                );
            }

            $projection = $record['stripped'] ?? null;
            if (!is_array($projection)) {
                $projection = $record['raw'] ?? null;
            }
            if (!is_array($projection)) {
                throw new RuntimeException("Revelation 1:{$verse} has no text.");
            }

            $verseText = preg_replace(
                '/\s+/u',
                ' ',
                trim(utf8Value($projection, "Revelation 1:{$verse} text"))
            );
            if (!is_string($verseText) || $verseText === '') {
                throw new RuntimeException("Revelation 1:{$verse} is empty.");
            }

            if (fwrite($entries, $line) !== strlen($line)) {
                throw new RuntimeException('Unable to write the NDJSON evidence.');
            }
            $displayLine = sprintf(
                "%s %d:%d %s\n",
                BOOK_NAME,
                CHAPTER_NUMBER,
                $verse,
                $verseText
            );
            if (fwrite($text, $displayLine) !== strlen($displayLine)) {
                throw new RuntimeException('Unable to write the text evidence.');
            }
            fwrite(STDOUT, $displayLine);
            $verses[$verse] = true;
        }
        if (!feof($input)) {
            throw new RuntimeException('Unable to read the complete KJV extraction.');
        }
    } finally {
        fclose($input);
        fclose($entries);
        fclose($text);
    }

    ksort($verses);
    $actualVerses = array_keys($verses);
    $expectedVerses = range(1, EXPECTED_VERSES);
    if ($actualVerses !== $expectedVerses) {
        throw new RuntimeException(
            'Revelation 1 is incomplete: expected verses 1-'
            . EXPECTED_VERSES
            . ', received '
            . implode(',', $actualVerses)
            . '.'
        );
    }

    $entrySha256 = hash_file('sha256', $entryPath);
    $textSha256 = hash_file('sha256', $textPath);
    if (!is_string($entrySha256) || !is_string($textSha256)) {
        throw new RuntimeException('Unable to hash the release evidence.');
    }

    $manifest = [
        'artifact_format' => 'getbible/sword-release-evidence/v1',
        'module' => MODULE,
        'reference' => BOOK_NAME . ' ' . CHAPTER_NUMBER,
        'canonical_book' => CANONICAL_BOOK_NUMBER,
        'testament' => TESTAMENT_NUMBER,
        'testament_book' => TESTAMENT_BOOK_NUMBER,
        'chapter' => CHAPTER_NUMBER,
        'verses' => EXPECTED_VERSES,
        'engine_version' => Engine::productVersion(),
        'abi_version' => Engine::abiVersion(),
        'contract' => Engine::contractIdentifier(),
        'whole_contract_stream' => false,
        'entries_file' => basename($entryPath),
        'entries_sha256' => $entrySha256,
        'text_file' => basename($textPath),
        'text_sha256' => $textSha256,
        'source_url' => SOURCE_URL,
        'source_sha256' => $sourceSha256,
    ];
    $encodedManifest = json_encode(
        $manifest,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
    ) . "\n";
    if (file_put_contents($manifestPath, $encodedManifest) !== strlen($encodedManifest)) {
        throw new RuntimeException('Unable to write the evidence manifest.');
    }

    fwrite(
        STDOUT,
        sprintf(
            "Created %d-verse KJV Revelation 1 evidence (%s).\n",
            EXPECTED_VERSES,
            $entrySha256
        )
    );
} finally {
    @unlink($fullStreamPath);
}
