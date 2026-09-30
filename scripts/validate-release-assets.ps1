[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -LiteralPath (Join-Path $repositoryRoot 'catalog-v1.json') -Raw | ConvertFrom-Json
$assetRoot = Join-Path $repositoryRoot 'release-assets'
$validated = 0

Add-Type -AssemblyName System.IO.Compression

foreach ($pack in $catalog.packs) {
    foreach ($version in $pack.versions) {
        $downloadUri = [Uri]$version.download
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
            }
            finally { $archive.Dispose() }
        }
        finally { $stream.Dispose() }
        $validated++
    }
}

Write-Host "Validated $validated deterministic release archives against catalog-v1.json."
