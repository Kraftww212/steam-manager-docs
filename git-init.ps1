# Publishes this folder to a Git repository for GitBook Git Sync.
#
# Run from this folder:
#   powershell -ExecutionPolicy Bypass -File .\git-init.ps1 -Remote https://github.com/USER/REPO.git
# Optional: -Name "Your Name" -Email "you@example.com"  (commit author, this repo only)
#
# The GitHub repository must exist and be EMPTY (no README, license or .gitignore).
# This file is ASCII-only on purpose: Windows PowerShell 5.1 reads UTF-8 files
# without BOM as ANSI, which breaks any non-ASCII text in the script.

param(
  [string]$Remote = '',
  [string]$Name = '',
  [string]$Email = ''
)

Set-Location -Path $PSScriptRoot

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail 'Git is not in PATH. Install Git for Windows and open a NEW PowerShell window.'
}

# 1. Repository (branch main)
if (-not (Test-Path .git)) {
  git init -b main
  if ($LASTEXITCODE -ne 0) { Fail 'git init failed.' }
}

# 2. Commit author (local to this repository, global git config is not touched)
$owner = ''
if ($Remote -match 'github\.com[:/]([^/]+)/') { $owner = $Matches[1] }
if ($Name)  { git config user.name  $Name }
if ($Email) { git config user.email $Email }
if (-not (git config user.name)) {
  if ($owner) { git config user.name $owner }
  else { Fail 'Commit author is not set. Re-run with -Name "Your Name" -Email "you@example.com".' }
}
if (-not (git config user.email)) {
  if ($owner) { git config user.email "$owner@users.noreply.github.com" }
  else { Fail 'Commit author email is not set. Re-run with -Email "you@example.com".' }
}
Write-Host ("Commit author: {0} <{1}>" -f (git config user.name), (git config user.email))

# 3. Commit everything that changed
git add -A
if ($LASTEXITCODE -ne 0) { Fail 'git add failed.' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -m 'docs: Steam Manager guide'
  if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }
} else {
  Write-Host 'Nothing new to commit.'
}
git branch -M main

# 4. Remote and push
if (-not $Remote) {
  Write-Host 'Local repository is ready. To publish, run:'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\git-init.ps1 -Remote https://github.com/USER/REPO.git'
  exit 0
}

$remotes = @(git remote)
if ($remotes -contains 'origin') { git remote set-url origin $Remote } else { git remote add origin $Remote }
if ($LASTEXITCODE -ne 0) { Fail 'Could not set remote origin.' }

# Pull edits made in GitBook (Git Sync commits to GitHub) before pushing ours.
git ls-remote --exit-code --heads origin main | Out-Null
if ($LASTEXITCODE -eq 0) {
  git pull --rebase origin main
  if ($LASTEXITCODE -ne 0) {
    git rebase --abort
    Fail 'Local edits conflict with edits made in GitBook. Nothing was pushed; ask for help.'
  }
}

git push -u origin main
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'Push failed. Common causes:' -ForegroundColor Yellow
  Write-Host ' - the repository does not exist or the URL has a typo;'
  Write-Host ' - the repository is not empty (created with README/license): delete it and create it empty;'
  Write-Host ' - the GitHub sign-in window was closed: run the script again and sign in.'
  exit 1
}

Write-Host ''
Write-Host "Done: pushed to $Remote (branch main)." -ForegroundColor Green
Write-Host 'Next: GitBook -> space Settings -> Git Sync -> GitHub -> this repo, branch main,'
Write-Host '      first sync direction GitHub -> GitBook.'
