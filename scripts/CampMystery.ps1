[CmdletBinding()]
param(
    [ValidateSet("Validate", "Build", "Serve", "Dev", "Release")]
    [string]$Action = "Dev",
    [switch]$NoPull,
    [string]$Observations = "",
    [string]$ReleaseCommit = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Invoke-Python {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 @Arguments
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        & python @Arguments
    }
    else {
        throw "Python 3 was not found. Install Python 3.12 or newer."
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed with exit code $LASTEXITCODE."
    }
}

function Get-DefaultBranch {
    Require-Command git

    [string]$RemoteHead = (& git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $RemoteHead) {
        return ($RemoteHead.Trim() -replace "^origin/", "")
    }

    foreach ($Candidate in @("main", "master")) {
        & git show-ref --verify --quiet "refs/remotes/origin/$Candidate"
        if ($LASTEXITCODE -eq 0) {
            return $Candidate
        }
    }

    $RemoteInfo = @(& git remote show origin 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($Line in $RemoteInfo) {
            if ($Line -match "HEAD branch:\s*(\S+)") {
                return $Matches[1]
            }
        }
    }

    throw "Unable to resolve origin's default branch. Fetch origin or repair origin/HEAD."
}

function Sync-DefaultBranch {
    if ($NoPull) {
        return
    }
    Require-Command git
    $Changes = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git working tree."
    }
    if ($Changes.Count -gt 0) {
        throw "The working tree is not clean. Commit, stash, or use -NoPull before continuing."
    }

    $DefaultBranch = Get-DefaultBranch
    & git fetch --prune origin $DefaultBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Could not fetch origin/$DefaultBranch."
    }

    & git show-ref --verify --quiet "refs/heads/$DefaultBranch"
    if ($LASTEXITCODE -eq 0) {
        & git switch $DefaultBranch
    }
    else {
        & git switch --track -c $DefaultBranch "origin/$DefaultBranch"
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Could not switch to the default branch '$DefaultBranch'."
    }

    & git merge --ff-only "origin/$DefaultBranch"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not fast-forward $DefaultBranch from origin/$DefaultBranch."
    }
    Write-Host "Synchronized default branch '$DefaultBranch'."
}

function Install-Tools {
    Require-Command rokit
    & rokit install
    if ($LASTEXITCODE -ne 0) {
        throw "rokit install failed."
    }
    Require-Command rojo
}

function Get-ReleaseCommit {
    if ($ReleaseCommit) {
        return $ReleaseCommit
    }
    Require-Command git
    $Commit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to resolve the current commit."
    }
    $Changes = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git working tree."
    }
    if ($Changes.Count -gt 0) {
        return "WORKTREE-BASED-ON-$Commit"
    }
    return $Commit
}

function Invoke-RepositoryGate {
    Install-Tools
    Invoke-Python scripts/release_gate.py --require-rojo --commit (Get-ReleaseCommit)
}

function Build-Place {
    Require-Command rojo
    New-Item -ItemType Directory -Force -Path build | Out-Null
    & rojo build default.project.json --output build/CAMP-Mystery.rbxlx
    if ($LASTEXITCODE -ne 0) {
        throw "Rojo build failed."
    }
    Write-Host "Built build/CAMP-Mystery.rbxlx"
}

switch ($Action) {
    "Validate" {
        Sync-DefaultBranch
        Invoke-RepositoryGate
    }
    "Build" {
        Sync-DefaultBranch
        Invoke-RepositoryGate
        Build-Place
    }
    "Serve" {
        Install-Tools
        & rojo serve
        if ($LASTEXITCODE -ne 0) {
            throw "Rojo serve failed."
        }
    }
    "Dev" {
        Sync-DefaultBranch
        Invoke-RepositoryGate
        Build-Place
        Write-Host "Repository checks passed. Starting Rojo on localhost:34872..."
        & rojo serve
        if ($LASTEXITCODE -ne 0) {
            throw "Rojo serve failed."
        }
    }
    "Release" {
        Sync-DefaultBranch
        Install-Tools
        if (-not $Observations) {
            throw "Release requires -Observations with a completed release observation JSON file."
        }
        $ObservationPath = (Resolve-Path $Observations).Path
        Invoke-Python scripts/release_gate.py --release-candidate --commit (Get-ReleaseCommit) --observations $ObservationPath
        Build-Place
        Write-Host "Release gate passed for commit $(Get-ReleaseCommit). Publishing is still a deliberate Roblox Creator Dashboard action."
    }
}
