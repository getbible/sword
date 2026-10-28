<?php
// SPDX-License-Identifier: GPL-2.0-only

declare(strict_types=1);

use GetBible\Sword\Engine;
use GetBible\Sword\Exception;

if ($argc !== 3) {
    fwrite(STDERR, "Usage: php integration.php SWORD_ROOT OUTPUT_DIRECTORY\n");
    exit(2);
}

[$script, $swordRoot, $outputDirectory] = $argv;
unset($script);

function assertTrue(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function streamToFile(callable $operation, string $path): void
{
    $stream = fopen($path, 'wb');
    if ($stream === false) {
        throw new RuntimeException("Unable to open test output: {$path}");
    }

    try {
        $bytes = $operation($stream);
    } finally {
        fclose($stream);
    }
    clearstatcache(true, $path);
    assertTrue(filesize($path) === $bytes, "Stream byte count differs: {$path}");
}

/** Decode authoritative bytes and verify the complete source envelope. */
function bytes(array $value): string
{
    $raw = base64_decode($value['base64'], true);
    assertTrue(
        $raw !== false
        && ($value['encoding'] ?? null) === 'base64'
        && base64_encode($raw) === $value['base64']
        && strlen($raw) === $value['size']
        && hash('sha256', $raw) === $value['sha256'],
        'Invalid source byte envelope.'
    );
    return $raw;
}

/** Keep only nonempty fixture entries, never an entire module export in memory. */
function inspectStream(string $path): array
{
    $stream = fopen($path, 'rb');
    if ($stream === false) {
        throw new RuntimeException("Unable to read test output: {$path}");
    }
    $modules = [];
    $entries = [];
    $diagnostics = [];
    $footer = null;
    $sequence = 0;
    $digest = hash_init('sha256');
    try {
        while (($line = fgets($stream)) !== false) {
            $record = json_decode($line, true, 512, JSON_THROW_ON_ERROR);
            assertTrue($footer === null, 'Records followed the stream footer.');
            assertTrue($record['sequence'] === $sequence++, 'Stream sequence changed.');
            if ($record['type'] === 'footer') {
                $footer = $record;
                assertTrue($footer['stream_sha256'] === hash_final($digest), 'Footer digest differs.');
                continue;
            }
            hash_update($digest, $line);
            if ($record['type'] === 'header') {
                assertTrue($sequence === 1, 'Header was not the first record.');
                assertTrue($record['contract'] === 'getbiblesword.ndjson/v1', 'Unexpected stream contract.');
                assertTrue($record['contract_version'] === 1, 'Unexpected contract version.');
            } elseif ($record['type'] === 'module') {
                $modules[bytes($record['name'])] = $record;
            } elseif ($record['type'] === 'entry' && bytes($record['raw']) !== '') {
                $entries[] = $record;
            } elseif ($record['type'] === 'diagnostic') {
                $diagnostics[] = $record;
            }
        }
        assertTrue(feof($stream), 'Failed while reading an NDJSON stream.');
    } finally {
        fclose($stream);
    }
    assertTrue($footer !== null && $footer['success'] === true, 'Missing or unsuccessful stream footer.');
    return ['modules' => $modules, 'entries' => $entries, 'diagnostics' => $diagnostics];
}

function attributes(array $entry): array
{
    $result = [];
    foreach ($entry['official_attributes'] as $group) {
        foreach ($group['lists'] as $item) {
            foreach ($item['values'] as $value) {
                $result[bytes($group['name'])][bytes($item['name'])][bytes($value['name'])]
                    = bytes($value['value']);
            }
        }
    }
    return $result;
}

function assertAttributes(array $entry, string $heading, string $footnote, string $lemma): void
{
    $values = attributes($entry);
    assertTrue(
        ($values['Heading']['Preverse']['0'] ?? null) === '<title canonical="true">' . $heading . '</title>',
        'SWORD current-entry heading was not preserved.'
    );
    assertTrue(
        ($values['Footnote']['1']['body'] ?? null) === '<p>' . $footnote . '</p>',
        'SWORD current-entry footnote was not preserved.'
    );
    assertTrue(($values['Word']['001']['Lemma'] ?? null) === $lemma, 'SWORD lexical lemma was not preserved.');
    assertTrue(($values['Word']['001']['Morph'] ?? null) === 'N-NSM', 'SWORD lexical morphology was not preserved.');
}

function normalized(array $entry, string $field): string
{
    assertTrue(isset($entry[$field]) && is_array($entry[$field]), "Missing {$field} projection.");
    $value = bytes($entry[$field]);
    assertTrue(preg_match('//u', $value) === 1, "{$field} is not valid UTF-8.");
    return $value;
}

assertTrue(is_dir($outputDirectory), 'Output directory does not exist.');
$engine = new Engine($swordRoot);
assertTrue($engine->modulePath() === $swordRoot, 'Explicit module path changed.');
assertTrue(Engine::abiVersion() === 1, 'Unexpected ABI version.');
assertTrue(Engine::productVersion() === '0.4.0', 'Unexpected engine version.');
assertTrue(Engine::contractIdentifier() === 'getbiblesword.ndjson/v1', 'Unexpected contract identifier.');

$expectedModules = [
    'PhpFixture' => ['RawText', 'bible'],
    'PhpCommentary' => ['RawCom', 'commentary'],
    'PhpDictionary' => ['RawLD', 'dictionary_or_lexicon'],
    'PhpLatin1' => ['RawLD', 'dictionary_or_lexicon'],
    'PhpInvalidUTF8' => ['RawLD', 'dictionary_or_lexicon'],
];

for ($run = 1; $run <= 2; ++$run) {
    streamToFile(
        static fn ($stream): int => $engine->streamModules($stream),
        "{$outputDirectory}/list-{$run}.ndjson"
    );
}
assertTrue(
    hash_file('sha256', "{$outputDirectory}/list-1.ndjson") === hash_file('sha256', "{$outputDirectory}/list-2.ndjson"),
    'Repeated module listings differ.'
);
$list = inspectStream("{$outputDirectory}/list-1.ndjson");
assertTrue(count($list['modules']) === count($expectedModules), 'Unexpected module count.');
$exports = [];
foreach ($expectedModules as $name => [$driver, $classification]) {
    assertTrue(isset($list['modules'][$name]), "Fixture module not listed: {$name}");
    assertTrue(bytes($list['modules'][$name]['driver']) === $driver, "Unexpected driver: {$name}");
    assertTrue($list['modules'][$name]['classification'] === $classification, "Unexpected classification: {$name}");
    for ($run = 1; $run <= 2; ++$run) {
        streamToFile(
            static fn ($stream): int => $engine->streamModule($name, $stream, Engine::MINIMUM_ARTIFACT_CHUNK_SIZE),
            "{$outputDirectory}/{$name}-{$run}.ndjson"
        );
    }
    assertTrue(
        hash_file('sha256', "{$outputDirectory}/{$name}-1.ndjson")
            === hash_file('sha256', "{$outputDirectory}/{$name}-2.ndjson"),
        "Repeated module extractions differ: {$name}"
    );
    $exports[$name] = inspectStream("{$outputDirectory}/{$name}-1.ndjson");
    assertTrue(count($exports[$name]['modules']) === 1, "Unexpected extraction module count: {$name}");
    assertTrue(isset($exports[$name]['modules'][$name]), "Wrong module was extracted: {$name}");
    if ($name !== 'PhpInvalidUTF8') {
        assertTrue($exports[$name]['diagnostics'] === [], "Unexpected extraction diagnostics: {$name}");
    }
}

$bible = $exports['PhpFixture']['entries'];
assertTrue(count($bible) === 2, 'Bible fixture entry count changed.');
assertTrue(bytes($bible[0]['scope']['osis_reference']) === 'Gen.1.1', 'Bible reference changed.');
assertTrue(str_contains(normalized($bible[0], 'normalized_raw'), 'strong:H7225'), 'Bible source markup was lost.');
assertTrue(trim(normalized($bible[1], 'normalized_stripped')) === 'In the beginning was the Word.', 'Bible text changed.');

$dictionary = $exports['PhpDictionary']['entries'];
assertTrue(count($dictionary) === 4, 'Dictionary entries, including duplicate keys, were lost.');
assertTrue(array_map(static fn (array $entry): string => bytes($entry['key']), $dictionary)
    === ['ALPHA', 'BETA', 'DUPLICATE', 'DUPLICATE'], 'Dictionary key order or duplicate keys changed.');
assertTrue(array_column($dictionary, 'ordinal') === [0, 1, 2, 3], 'Dictionary traversal ordinals changed.');
// Pinned SWORD imp2ld inserts equal keys before the existing index entry. The
// contract preserves that official traversal order, not IMP source-file order.
assertTrue(trim(bytes($dictionary[2]['raw'])) === 'Second definition for the same repeated dictionary key.', 'First traversed duplicate definition changed.');
assertTrue(trim(bytes($dictionary[3]['raw'])) === 'First definition for a repeated dictionary key.', 'Second traversed duplicate definition changed.');
assertTrue(normalized($dictionary[0], 'normalized_raw') === bytes($dictionary[0]['raw']), 'Valid UTF-8 source bytes changed.');
assertTrue(str_contains(normalized($dictionary[0], 'normalized_stripped'), 'café'), 'Dictionary Unicode text was lost.');
assertTrue(!str_contains(normalized($dictionary[0], 'normalized_stripped'), 'Dictionary footnote'), 'Dictionary footnote leaked into stripped text.');
assertAttributes($dictionary[0], 'Dictionary heading', 'Dictionary footnote.', 'G0001');
assertTrue(attributes($dictionary[1]) === [], 'Dictionary attributes leaked into the next entry.');

$commentary = $exports['PhpCommentary']['entries'];
assertTrue(count($commentary) === 3, 'Commentary entries were lost.');
assertTrue(array_map(static fn (array $entry): string => bytes($entry['scope']['osis_reference']), $commentary)
    === ['Gen.1.1', 'John.1.1', 'Rev.22.21'], 'Commentary canonical references changed.');
foreach ($commentary as $entry) {
    assertTrue($entry['scope']['type'] === 'verse_key', 'Commentary lost its verse scope.');
    assertTrue($entry['scope']['intro_scope'] === 'verse', 'Commentary reference scope changed.');
}
assertAttributes($commentary[0], 'Commentary heading', 'Commentary footnote.', 'H7225');
assertTrue(attributes($commentary[1]) === [], 'Commentary attributes leaked into the next entry.');
assertTrue(str_contains(normalized($commentary[0], 'normalized_stripped'), '— an original comment.'), 'Commentary Unicode text changed.');
assertTrue(trim(normalized($commentary[2], 'normalized_stripped')) === 'A final comment: grace and peace.', 'Final commentary text changed.');

$latin1 = $exports['PhpLatin1']['entries'];
assertTrue(count($latin1) === 2, 'Latin-1 dictionary entry count changed.');
assertTrue(str_contains(bytes($latin1[0]['raw']), "caf\xe9"), 'Latin-1 source bytes were not preserved.');
assertTrue(!str_contains(bytes($latin1[0]['raw']), 'café'), 'Legacy raw bytes were silently converted.');
assertTrue(str_contains(normalized($latin1[0], 'normalized_raw'), 'café'), 'Latin-1 markup was not normalized.');
assertTrue(trim(normalized($latin1[0], 'normalized_stripped')) === 'café <G0001> and naïve.', 'Latin-1 text or its default SWORD lexical projection changed.');

$invalid = $exports['PhpInvalidUTF8']['entries'];
assertTrue(count($invalid) === 2, 'Malformed source entry was discarded.');
assertTrue(str_contains(bytes($invalid[0]['raw']), "\xff"), 'Malformed source bytes were not preserved.');
assertTrue(array_key_exists('normalized_raw', $invalid[0]) && $invalid[0]['normalized_raw'] === null, 'Invalid UTF-8 was normalized.');
assertTrue(array_key_exists('normalized_stripped', $invalid[0]) && $invalid[0]['normalized_stripped'] === null, 'Invalid UTF-8 gained a stripped projection.');
assertTrue(in_array('entry.encoding.unavailable', array_column($exports['PhpInvalidUTF8']['diagnostics'], 'code'), true), 'Encoding failure diagnostic was lost.');
assertTrue(trim(normalized($invalid[1], 'normalized_stripped')) === 'A clean second entry.', 'Encoding failure contaminated the next entry.');

$failedStream = fopen('php://temp', 'w+b');
assertTrue(is_resource($failedStream), 'Unable to create failed-operation stream.');
try {
    $engine->streamModule('MissingModule', $failedStream);
    throw new RuntimeException('Missing module did not throw.');
} catch (Exception $exception) {
    assertTrue($exception->getCode() === 2, 'Missing module did not return extraction-failed status.');
}
rewind($failedStream);
$failedOutput = stream_get_contents($failedStream);
fclose($failedStream);
assertTrue(is_string($failedOutput) && str_contains($failedOutput, '"success":false'), 'Failed extraction did not preserve its NDJSON failure footer.');

fwrite(STDOUT, "PHP Bible, commentary, dictionary, encoding, attribute and repetition checks passed.\n");
