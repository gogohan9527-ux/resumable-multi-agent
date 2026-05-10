# scaffold-docs.ps1 - bootstrap docs/ for a resumable-multi-agent project (Windows / PowerShell)
#
# Usage:
#   .\scaffold-docs.ps1 -ProjectRoot "D:\path\to\project" -ProjectName "my-app" `
#                       [-LaneA "backend"] [-LaneB "frontend"] [-Contract "interface"]
#
# What it does:
#   1. Creates <ProjectRoot>\docs\ if missing.
#   2. Copies the four asset templates into docs\ (renamed: subagent-prompt.template.md becomes
#      docs\_subagent-prompt.template.md, an orchestrator reference deleted during Phase C cleanup).
#   3. Replaces the most common placeholders (<Project Name>, <Lane A Name>, <Lane B Name>, <contract>)
#      across the four files in one pass.
#
# It does not fill in PRD content, explanation sections 3+ (naming/run-commands/etc.), or todolist rows.
# Those require human/orchestrator judgement per project. This script only removes the mechanical
# copy-and-replace work so the orchestrator can start writing actual content immediately.
#
# This script is for first-run initialization only. On follow-up runs, the script refuses to overwrite.
# The orchestrator should instead:
#   - Read the existing persistent docs (prd.md, explanation.md, contract, todolist.md).
#   - Have lanes write contract additions to docs\<contract>.draft.md, not the persistent file.
#   - In Phase C, merge drafts into persistent files with deprecation/version markers and append
#     a new dated section to docs\todolist.md. See SKILL.md "Phase C - Merge and Cleanup".

param(
    [Parameter(Mandatory=$true)] [string] $ProjectRoot,
    [Parameter(Mandatory=$true)] [string] $ProjectName,
    [string] $LaneA = "<Lane A Name>",
    [string] $LaneB = "<Lane B Name>",
    [string] $Contract = "interface"
)

$ErrorActionPreference = "Stop"

$skillDir = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $skillDir "assets"
$docsDir = Join-Path $ProjectRoot "docs"

if (Test-Path $docsDir) {
    Write-Error "docs\ already exists at $docsDir; refusing to overwrite. Delete or move it first."
}

if (-not (Test-Path $assetsDir)) {
    Write-Error "Assets directory not found at $assetsDir. Is the skill installed correctly?"
}

New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

# Map source asset filename to target filename inside docs/.
$copies = @{
    "prd.template.md"             = "prd.md"
    "explanation.template.md"     = "explanation.md"
    "todolist.template.md"        = "todolist.md"
    "subagent-prompt.template.md" = "_subagent-prompt.template.md"
}

foreach ($src in $copies.Keys) {
    $srcPath = Join-Path $assetsDir $src
    $dstPath = Join-Path $docsDir $copies[$src]
    $content = Get-Content -Raw -LiteralPath $srcPath
    $content = $content.Replace("<Project Name>", $ProjectName)
    $content = $content.Replace("<Lane A Name>", $LaneA)
    $content = $content.Replace("<Lane B Name>", $LaneB)
    $content = $content.Replace("<Lane A>", $LaneA)
    $content = $content.Replace("<Lane B>", $LaneB)
    $content = $content.Replace("<contract>", $Contract)
    Set-Content -LiteralPath $dstPath -Value $content -Encoding utf8
    Write-Host "  wrote $($copies[$src])"
}

Write-Host ""
Write-Host "Scaffolded docs at: $docsDir"
Write-Host ""
Write-Host "Next steps for the orchestrator:"
Write-Host "  1. Fill in docs\prd.md sections 1-10 from the user dialogue."
Write-Host "  2. Fill in docs\explanation.md section 1 (repo tree), section 3 (naming),"
Write-Host "     section 4 (per-lane conventions), section 7 (testing), and section 8 (run commands)."
Write-Host "  3. Draft docs\todolist.md rows for each lane. Run the row-granularity self-check"
Write-Host "     in SKILL.md before finalizing."
Write-Host "  4. docs\_subagent-prompt.template.md is a reference for writing each subagent's"
Write-Host "     launch prompt, not a doc the project tracks. Move or delete it after Phase B."
