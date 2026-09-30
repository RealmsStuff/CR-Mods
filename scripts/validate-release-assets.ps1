[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -LiteralPath (Join-Path $repositoryRoot 'catalog-v1.json') -Raw | ConvertFrom-Json
$assetRoot = Join-Path $repositoryRoot 'release-assets'
$sourceRoot = Join-Path $repositoryRoot 'packs'
$validated = 0

Add-Type -AssemblyName System.IO.Compression

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
                foreach ($entry in $archive.Entries) {
                    if ($entry.FullName.EndsWith('/')) { continue }
                    $entryPath = $entry.FullName.Replace('\', '/')
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
                    $sourceDigest = (Get-FileHash -LiteralPath $sourceFiles[$relative] -Algorithm SHA256).Hash
                    $entryStream = $archiveFiles[$relative].Open()
                    try {
                        $sha = [System.Security.Cryptography.SHA256]::Create()
                        try { $archiveDigest = [BitConverter]::ToString($sha.ComputeHash($entryStream)).Replace('-', '') }
                        finally { $sha.Dispose() }
                    }
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
