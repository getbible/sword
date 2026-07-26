<?php

declare(strict_types=1);

use GetBible\Sword\Engine;

const MODULE = 'KJV';
const CANONICAL_BOOK_NUMBER = 66;
const TESTAMENT_NUMBER = 2;
const TESTAMENT_BOOK_NUMBER = 27;
const BOOK_NAME = 'Revelation';
const CHAPTERS = [
    1 => 20,
    22 => 21,
];
const FIXTURE = [
    'kind' => 'approved-baseline-replay',
    'paths' => [
        'tests/baselines/kjv-revelation-1/kjv-revelation-1.entries.ndjson',
        'tests/baselines/kjv-revelation-22/kjv-revelation-22.entries.ndjson',
    ],
];

if ($argc !== 3) {
    fwrite(
        STDERR,
        "Usage: php create-kjv-revelation-boundary-artifacts.php "
        . "SWORD_ROOT OUTPUT_DIRECTORY\n"
    );
    exit(2);
}

[$script, $swordRoot, $outputDirectory] = $argv;
unset($script);

if (!extension_loaded('getbiblesword')) {
    throw new RuntimeException('The getbiblesword extension is not loaded.');
}
if (!is_dir($outputDirectory) && !mkdir($outputDirectory, 0777, true)) {
    throw new RuntimeException("Unable to create output directory: {$outputDirectory}");
}

$fullStreamPath = tempnam(sys_get_temp_dir(), 'gbs-kjv-');
if ($fullStreamPath === false) {
    throw new RuntimeException('Unable to create the temporary extraction file.');
}

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

/**
 * @return resource
 */
function openOutput(string $path)
{
    $stream = fopen($path, 'wb');
    if ($stream === false) {
        throw new RuntimeException("Unable to open output file: {$path}");
    }

    return $stream;
}

function artifactPrefix(int $chapter): string
{
    return "kjv-revelation-{$chapter}";
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

    $entries = [];
    $texts = [];
    $entryPaths = [];
    $textPaths = [];
    $verses = [];
    foreach (CHAPTERS as $chapter => $expectedVerses) {
        $prefix = artifactPrefix($chapter);
        $entryPaths[$chapter] = "{$outputDirectory}/{$prefix}.entries.ndjson";
        $textPaths[$chapter] = "{$outputDirectory}/{$prefix}.txt";
        $entries[$chapter] = openOutput($entryPaths[$chapter]);
        $texts[$chapter] = openOutput($textPaths[$chapter]);
        $verses[$chapter] = [];
    }

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
                || ($scope['book'] ?? null) !== TESTAMENT_BOOK_NUMBER) {
                continue;
            }

            $chapter = $scope['chapter'] ?? null;
            if (!is_int($chapter) || !array_key_exists($chapter, CHAPTERS)) {
                continue;
            }

            $expectedVerses = CHAPTERS[$chapter];
            $verse = $scope['verse'] ?? null;
            if (!is_int($verse) || $verse < 1 || $verse > $expectedVerses) {
                throw new RuntimeException(
                    "Unexpected Revelation {$chapter} verse number."
                );
            }
            if (isset($verses[$chapter][$verse])) {
                throw new RuntimeException(
                    "Duplicate Revelation {$chapter}:{$verse} entry."
                );
            }

            $osis = utf8Value($scope['osis_reference'] ?? [], 'OSIS reference');
            $expectedOsis = "Rev.{$chapter}.{$verse}";
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
                throw new RuntimeException(
                    "Revelation {$chapter}:{$verse} has no text."
                );
            }

            $verseText = preg_replace(
                '/\s+/u',
                ' ',
                trim(
                    utf8Value(
                        $projection,
                        "Revelation {$chapter}:{$verse} text"
                    )
                )
            );
            if (!is_string($verseText) || $verseText === '') {
                throw new RuntimeException(
                    "Revelation {$chapter}:{$verse} is empty."
                );
            }

            if (fwrite($entries[$chapter], $line) !== strlen($line)) {
                throw new RuntimeException(
                    "Unable to write Revelation {$chapter} NDJSON evidence."
                );
            }
            $displayLine = sprintf(
                "%s %d:%d %s\n",
                BOOK_NAME,
                $chapter,
                $verse,
                $verseText
            );
            if (fwrite($texts[$chapter], $displayLine) !== strlen($displayLine)) {
                throw new RuntimeException(
                    "Unable to write Revelation {$chapter} text evidence."
                );
            }
            fwrite(STDOUT, $displayLine);
            $verses[$chapter][$verse] = true;
        }
        if (!feof($input)) {
            throw new RuntimeException('Unable to read the complete KJV extraction.');
        }
    } finally {
        fclose($input);
        foreach ($entries as $stream) {
            fclose($stream);
        }
        foreach ($texts as $stream) {
            fclose($stream);
        }
    }

    foreach (CHAPTERS as $chapter => $expectedVerseCount) {
        ksort($verses[$chapter]);
        $actualVerses = array_keys($verses[$chapter]);
        $expectedVerses = range(1, $expectedVerseCount);
        if ($actualVerses !== $expectedVerses) {
            throw new RuntimeException(
                "Revelation {$chapter} is incomplete: expected verses 1-"
                . $expectedVerseCount
                . ', received '
                . implode(',', $actualVerses)
                . '.'
            );
        }

        $entrySha256 = hash_file('sha256', $entryPaths[$chapter]);
        $textSha256 = hash_file('sha256', $textPaths[$chapter]);
        if (!is_string($entrySha256) || !is_string($textSha256)) {
            throw new RuntimeException(
                "Unable to hash Revelation {$chapter} evidence."
            );
        }

        $prefix = artifactPrefix($chapter);
        $manifestPath = "{$outputDirectory}/{$prefix}.manifest.json";
        $manifest = [
            'artifact_format' => 'getbible/sword-release-evidence/v2',
            'module' => MODULE,
            'reference' => BOOK_NAME . ' ' . $chapter,
            'canonical_book' => CANONICAL_BOOK_NUMBER,
            'testament' => TESTAMENT_NUMBER,
            'testament_book' => TESTAMENT_BOOK_NUMBER,
            'chapter' => $chapter,
            'verses' => $expectedVerseCount,
            'engine_version' => Engine::productVersion(),
            'abi_version' => Engine::abiVersion(),
            'contract' => Engine::contractIdentifier(),
            'whole_contract_stream' => false,
            'entries_file' => basename($entryPaths[$chapter]),
            'entries_sha256' => $entrySha256,
            'text_file' => basename($textPaths[$chapter]),
            'text_sha256' => $textSha256,
            'fixture' => FIXTURE,
        ];
        $encodedManifest = json_encode(
            $manifest,
            JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        ) . "\n";
        if (file_put_contents($manifestPath, $encodedManifest)
            !== strlen($encodedManifest)) {
            throw new RuntimeException(
                "Unable to write Revelation {$chapter} evidence manifest."
            );
        }

        fwrite(
            STDOUT,
            sprintf(
                "Created %d-verse KJV Revelation %d evidence (%s).\n",
                $expectedVerseCount,
                $chapter,
                $entrySha256
            )
        );
    }
} finally {
    @unlink($fullStreamPath);
}
