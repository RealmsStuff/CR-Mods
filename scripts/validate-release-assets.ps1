[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -LiteralPath (Join-Path $repositoryRoot 'catalog-v1.json') -Raw | ConvertFrom-Json
$assetRoot = Join-Path $repositoryRoot 'release-assets'
$sourceRoot = Join-Path $repositoryRoot 'packs'
$validated = 0

Add-Type -AssemblyName System.IO.Compression

function Test-WindowsDeviceName {
	param([Parameter(Mandatory)] [string] $Part)
	$stem = [IO.Path]::GetFileNameWithoutExtension($Part).ToUpperInvariant()
	return $stem -in @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5',
		'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
}

function Get-ComparableHash {
	param(
		[Parameter(Mandatory)] [IO.Stream] $Stream,
		[Parameter(Mandatory)] [bool] $NormalizeLineEndings
	)
	$sha = [Security.Cryptography.SHA256]::Create()
	try {
		if (-not $NormalizeLineEndings) {
			return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '')
		}
		$copy = [IO.MemoryStream]::new()
		try { $Stream.CopyTo($copy); $bytes = $copy.ToArray() }
		finally { $copy.Dispose() }
		$normalized = [Collections.Generic.List[byte]]::new($bytes.Length)
		for ($index = 0; $index -lt $bytes.Length; $index++) {
			if ($bytes[$index] -eq 13 -and $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) { continue }
			$normalized.Add($bytes[$index])
		}
		return [BitConverter]::ToString($sha.ComputeHash($normalized.ToArray())).Replace('-', '')
	}
	finally { $sha.Dispose() }
}

foreach ($pack in $catalog.packs) {
    foreach ($version in $pack.versions) {
        $downloadUri = [Uri]$version.download
		$repositoryUri = [Uri]$pack.sourceRepository
		$repositoryParts = $repositoryUri.AbsolutePath.Trim('/').Split('/')
		$downloadParts = $downloadUri.AbsolutePath.Trim('/').Split('/')
		if ($downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ne 'raw.githubusercontent.com' -or
			$downloadParts.Length -ne 5 -or $downloadParts[0] -ne $repositoryParts[0] -or
			$downloadParts[1] -ne $repositoryParts[1] -or $downloadParts[2] -ne 'main' -or
			$downloadParts[3] -ne 'release-assets') {
			throw "Catalog download is not a pack-local raw release asset: $($version.download)"
		}
        $fileName = [Uri]::UnescapeDataString($downloadUri.Segments[-1])
        $archivePath = Join-Path $assetRoot $fileName
        if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
            throw "Catalog archive is missing: $fileName"
        }
        $archiveFile = Get-Item -LiteralPath $archivePath
        if ($archiveFile.Length -ne [long]$version.sizeBytes) {
            throw "Catalog size does not match $fileName. Expected $($version.sizeBytes), got $($archiveFile.Length)."
        }
        $digest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($digest -ne $version.sha256.ToLowerInvariant()) {
            throw "Catalog SHA-256 does not match $fileName."
        }

        $stream = [System.IO.File]::OpenRead($archivePath)
        try {
            $archive = [System.IO.Compression.ZipArchive]::new($stream,
                [System.IO.Compression.ZipArchiveMode]::Read, $false)
            try {
                $manifestEntry = $archive.GetEntry('manifest.json')
                if ($null -eq $manifestEntry) { throw "$fileName has no root manifest.json." }
                $reader = [System.IO.StreamReader]::new($manifestEntry.Open())
                try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
                finally { $reader.Dispose() }
                if ($manifest.id -ne $pack.id -or $manifest.version -ne $version.version -or
                    [int]$manifest.modApiVersion -ne [int]$version.modApiVersion) {
                    throw "$fileName manifest identity does not match its catalog entry."
                }
                $manifestDependencies = @($manifest.dependencies | ForEach-Object { "$($_.id)|$($_.version)" } | Sort-Object)
                $catalogDependencies = @($version.dependencies | ForEach-Object { "$($_.id)|$($_.version)" } | Sort-Object)
                if (($manifestDependencies -join ',') -ne ($catalogDependencies -join ',')) {
                    throw "$fileName manifest dependencies do not match its catalog entry."
                }
                $manifestConflicts = @($manifest.conflicts | Sort-Object)
                $catalogConflicts = @($version.conflicts | Sort-Object)
                if (($manifestConflicts -join ',') -ne ($catalogConflicts -join ',')) {
                    throw "$fileName manifest conflicts do not match its catalog entry."
                }

                $packSource = Join-Path $sourceRoot $pack.id
                if (-not (Test-Path -LiteralPath $packSource -PathType Container)) {
                    throw "Catalog source pack is missing: $($pack.id)"
                }
                $sourceFiles = @{}
                foreach ($sourceFile in Get-ChildItem -LiteralPath $packSource -File -Recurse) {
                    $relative = $sourceFile.FullName.Substring($packSource.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
                    $sourceFiles[$relative] = $sourceFile.FullName
                }
                $archiveFiles = @{}
				$rawArchivePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($entry in $archive.Entries) {
					$rawPath = $entry.FullName
					$parts = @($rawPath.TrimEnd('/').Split('/'))
					$isUnsafe = [string]::IsNullOrWhiteSpace($rawPath) -or $rawPath.StartsWith('/') -or
						$rawPath.Contains('\') -or $rawPath.Contains(':') -or
						$rawPath.IndexOfAny([char[]]@('<', '>', '"', '|', '?', '*')) -ge 0 -or
						@($parts | Where-Object {
							[string]::IsNullOrEmpty($_) -or $_ -eq '.' -or $_ -eq '..' -or
							$_.EndsWith('.') -or $_.EndsWith(' ') -or (Test-WindowsDeviceName $_)
						}).Count -gt 0
					if ($isUnsafe -or -not $rawArchivePaths.Add($rawPath.TrimEnd('/'))) {
						throw "$fileName contains an unsafe or duplicate path: $rawPath"
					}
					$unixType = ($entry.ExternalAttributes -shr 16) -band 0xf000
					if (($unixType -ne 0 -and $unixType -ne 0x8000 -and $unixType -ne 0x4000) -or
						($entry.ExternalAttributes -band [int][IO.FileAttributes]::ReparsePoint) -ne 0) {
						throw "$fileName contains a link or special file: $rawPath"
					}
                    if ($entry.FullName.EndsWith('/')) { continue }
					$entryPath = $entry.FullName
                    if ($archiveFiles.ContainsKey($entryPath)) {
                        throw "$fileName contains duplicate entry $entryPath."
                    }
                    $archiveFiles[$entryPath] = $entry
                }
                $sourceNames = @($sourceFiles.Keys | Sort-Object)
                $archiveNames = @($archiveFiles.Keys | Sort-Object)
                if (($sourceNames -join "`n") -cne ($archiveNames -join "`n")) {
                    $missing = @($sourceNames | Where-Object { -not $archiveFiles.ContainsKey($_) })
                    $extra = @($archiveNames | Where-Object { -not $sourceFiles.ContainsKey($_) })
                    throw "$fileName differs from packs/$($pack.id) (missing: $($missing -join ', '); extra: $($extra -join ', '))."
                }
                foreach ($relative in $sourceNames) {
					$extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
					$normalizeLineEndings = $extension -eq '.json' -or $extension -eq '.md'
					$sourceStream = [IO.File]::OpenRead($sourceFiles[$relative])
					try { $sourceDigest = Get-ComparableHash $sourceStream $normalizeLineEndings }
					finally { $sourceStream.Dispose() }
                    $entryStream = $archiveFiles[$relative].Open()
					try { $archiveDigest = Get-ComparableHash $entryStream $normalizeLineEndings }
                    finally { $entryStream.Dispose() }
                    if ($sourceDigest -cne $archiveDigest) {
                        throw "$fileName entry $relative does not match packs/$($pack.id)."
                    }
                }
            }
            finally { $archive.Dispose() }
        }
        finally { $stream.Dispose() }
        $validated++
    }
}

Write-Host "Validated $validated release archives against catalog-v1.json and their source packs."
