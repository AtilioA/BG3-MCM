param(
    [string[]]$Files = @(),
    [string]$Filter = "",
    [string]$LuaLSPath = "",
    # 1 = errors only, 2 = errors and warnings.
    [ValidateRange(1, 2)]
    [int]$MaxSeverity = 2
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$luaRootPrefix = "Mod Configuration Menu/Mods/BG3MCM/ScriptExtender/Lua/"

# Validate requested -Files upfront so typos never silently report 0
$requestedRelPaths = @()
if ($Files.Count -gt 0) {
    $expandedFiles = @()
    foreach ($entry in $Files) {
        foreach ($part in ($entry -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed -ne "") { $expandedFiles += $trimmed }
        }
    }
    foreach ($f in $expandedFiles) {
        $norm = ($f -replace '\\', '/').TrimStart('./')
        $candidateFull = Join-Path $repoRoot ($norm -replace '/', '\')
        $candidateLua = Join-Path $repoRoot (($luaRootPrefix + $norm) -replace '/', '\')

        if (Test-Path -LiteralPath $candidateFull -PathType Leaf) {
            $requestedRelPaths += $norm
        } elseif (Test-Path -LiteralPath $candidateLua -PathType Leaf) {
            $requestedRelPaths += ($luaRootPrefix + $norm)
        } else {
            Write-Error "Requested file does not exist on disk: $f"
            exit 2
        }
    }
}

# Resolve LuaLS executable
$exe = $null
if ($LuaLSPath -ne "") {
    if (-not (Test-Path -LiteralPath $LuaLSPath -PathType Leaf)) {
        Write-Error "Specified -LuaLSPath does not exist: $LuaLSPath"
        exit 2
    }
    $exe = (Resolve-Path -LiteralPath $LuaLSPath).Path
} else {
    $bg3LintDir = Join-Path $env:LOCALAPPDATA "bg3-lint"
    if (Test-Path -LiteralPath $bg3LintDir -PathType Container) {
        $candidates = Get-ChildItem -LiteralPath $bg3LintDir -Directory -Filter "lua-language-server-*" |
            Sort-Object Name -Descending
        foreach ($dir in $candidates) {
            $binExe = Join-Path $dir.FullName "bin\lua-language-server.exe"
            if (Test-Path -LiteralPath $binExe -PathType Leaf) {
                $exe = $binExe
                break
            }
        }
    }
    if (-not $exe) {
        $cmd = Get-Command "lua-language-server" -ErrorAction SilentlyContinue
        if ($cmd) {
            $exe = $cmd.Source
        }
    }
}

if (-not $exe) {
    Write-Error "Could not locate lua-language-server executable."
    exit 2
}

$version = (& $exe --version 2>&1) | Out-String
Write-Output "LuaLS: $exe ($($version.Trim()))"

$configPath = (Resolve-Path -LiteralPath ".luarc.json").Path

# Without the BG3SE stubs LuaLS treats BG3SE types as unknown and reports a false 0.
$stubPath = Join-Path $repoRoot "../BG3-lint/luals/bg3se/library/ExtIdeHelpers.lua"
if (-not (Test-Path -LiteralPath $stubPath -PathType Leaf)) {
    Write-Warning "Skipping LuaLS check: BG3SE stubs not found at $stubPath. Clone BG3-lint next to this repo to enable it."
    exit 0
}
$tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) ("luals-check-" + [System.Guid]::NewGuid().ToString("N") + ".json")

try {
    $null = & $exe --check . --configpath $configPath --checklevel=Warning --check_out_path $tmpJson 2>&1

    if (-not (Test-Path -LiteralPath $tmpJson -PathType Leaf)) {
        Write-Error "LuaLS did not create output file: $tmpJson"
        exit 2
    }

    $rawJson = Get-Content -LiteralPath $tmpJson -Raw
    if ([string]::IsNullOrWhiteSpace($rawJson)) {
        Write-Output "Total diagnostics (severity <= $MaxSeverity): 0 across 0 files"
        exit 0
    }

    $data = $rawJson | ConvertFrom-Json
    $repoRootNorm = (($repoRoot -replace '\\', '/').TrimEnd('/')) + "/"

    $totalErrors = 0
    $filesWithErrors = 0

    foreach ($prop in $data.PSObject.Properties) {
        $uri = $prop.Name
        $diags = $prop.Value

        # Convert file:/// URI to repo-relative path with forward slashes
        $path = [System.Uri]::UnescapeDataString($uri)
        if ($path -match '^file:///([A-Za-z]:/.*)$') {
            $path = $Matches[1]
        } elseif ($path -match '^file://(.*)$') {
            $path = $Matches[1]
        }
        $path = $path -replace '\\', '/'

        if ($path.StartsWith($repoRootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relPath = $path.Substring($repoRootNorm.Length)
        } else {
            continue
        }

        if (-not $relPath.StartsWith("Mod Configuration Menu/", [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if ($requestedRelPaths.Count -gt 0) {
            $matched = $false
            foreach ($req in $requestedRelPaths) {
                if ($relPath.Equals($req, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) { continue }
        }

        if ($Filter -ne "" -and $relPath.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            continue
        }

        $sev1 = @($diags | Where-Object { $_.severity -le $MaxSeverity })
        if ($sev1.Count -eq 0) { continue }

        $filesWithErrors++
        foreach ($d in $sev1) {
            $totalErrors++
            $line = 1
            if ($d.range -and $d.range.start -and $null -ne $d.range.start.line) {
                $line = [int]$d.range.start.line + 1
            }
            $code = if ($d.code) { $d.code } else { "unknown" }
            $msg = ($d.message -replace '\r?\n', ' ').Trim()
            $level = if ($d.severity -eq 1) { "error" } else { "warning" }
            Write-Output "${relPath}:${line} $level [$code] $msg"
        }
    }

    Write-Output "Total diagnostics (severity <= $MaxSeverity): $totalErrors across $filesWithErrors files"
    if ($totalErrors -eq 0) {
        exit 0
    } else {
        exit 1
    }
} finally {
    if (Test-Path -LiteralPath $tmpJson -PathType Leaf) {
        Remove-Item -LiteralPath $tmpJson -Force -ErrorAction SilentlyContinue
    }
}
