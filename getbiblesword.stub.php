<?php

/**
 * @generate-class-entries
 * @generate-legacy-arginfo 80200
 */

namespace GetBible\Sword;

final class Engine
{
    public const ABI_VERSION = 1;
    public const DEFAULT_ARTIFACT_CHUNK_SIZE = 1048576;
    public const MINIMUM_ARTIFACT_CHUNK_SIZE = 4096;
    public const MAXIMUM_ARTIFACT_CHUNK_SIZE = 16777216;

    public function __construct(?string $modulePath = null) {}

    public static function abiVersion(): int {}

    public static function productVersion(): string {}

    public static function contractIdentifier(): string {}

    public function modulePath(): string {}

    /**
     * @param resource $destination
     */
    public function streamModules(mixed $destination): int {}

    /**
     * @param resource $destination
     */
    public function streamModule(
        string $module,
        mixed $destination,
        int $artifactChunkSize = 1048576
    ): int {}
}

class Exception extends \RuntimeException {}
