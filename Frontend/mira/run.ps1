param(
    [ValidateSet('run', 'verify', 'build')]
    [string]$Mode = 'run'
)

# Flutter's native shader compiler and test runner can fail on non-ASCII paths.
# Use temporary drive aliases; no SDK or project files are moved.
$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction Stop
$sdkPath = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
$usedDrives = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name })
$freeDrives = @('P', 'O', 'N', 'M', 'L', 'K', 'J', 'I', 'H', 'G' | Where-Object { $_ -notin $usedDrives })
if ($freeDrives.Count -lt 2) { throw 'Two unused drive letters are required.' }
$sdkDrive = $freeDrives[0] + ':'
$appDrive = $freeDrives[1] + ':'
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$sdkMapped = $false
$appMapped = $false
$locationPushed = $false
try {
    & subst.exe $sdkDrive $sdkPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the Flutter SDK drive alias.' }
    $sdkMapped = $true
    & subst.exe $appDrive $projectPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the project drive alias.' }
    $appMapped = $true
    Push-Location ($appDrive + '\')
    $locationPushed = $true
    $tempPath = $appDrive + '\.dart_tool\mira_temp'
    New-Item -ItemType Directory -Force $tempPath | Out-Null
    $env:TEMP = $tempPath
    $env:TMP = $tempPath
    $flutter = $sdkDrive + '\bin\flutter.bat'
    if ($Mode -eq 'verify') {
        & $flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
        & $flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    } elseif ($Mode -eq 'build') {
        & $flutter build web --no-wasm-dry-run
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    } else {
        & $flutter run -d chrome
        if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed.' }
    }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    if ($locationPushed) { Pop-Location }
    if ($appMapped) { & subst.exe $appDrive /D }
    if ($sdkMapped) { & subst.exe $sdkDrive /D }
    # Restore package paths for editors after the temporary SDK alias is removed.
    Push-Location $projectPath
    try {
        & $flutterCommand.Source pub get --offline
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Run flutter pub get to restore editor package paths.' }
    } finally { Pop-Location }
}
