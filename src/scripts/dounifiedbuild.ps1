# Unified build script for Windows, Linux and Mac builder. Run on a Windows machine inside powershell.
param (
    [Parameter(Mandatory=$true)][string]$version,
    [Parameter(Mandatory=$true)][string]$prev,
    [Parameter(Mandatory=$true)][string]$server
)

Write-Host "[Initializing]"
Remove-Item -Force -ErrorAction Ignore ./artifacts/linux-binaries-YecLite-v$version.tar.gz
Remove-Item -Force -ErrorAction Ignore ./artifacts/linux-deb-YecLite-v$version.deb
Remove-Item -Force -ErrorAction Ignore ./artifacts/Windows-binaries-YecLite-v$version.zip
Remove-Item -Force -ErrorAction Ignore ./artifacts/macOS-YecLite-v$version.dmg
Remove-Item -Force -ErrorAction Ignore ./artifacts/signatures-v$version.tar.gz


Remove-Item -Recurse -Force -ErrorAction Ignore ./bin
Remove-Item -Recurse -Force -ErrorAction Ignore ./debug
Remove-Item -Recurse -Force -ErrorAction Ignore ./release

# Create the version.h file and update README version number
Write-Output "#define APP_VERSION `"$version`"" > src/version.h
Get-Content README.md | Foreach-Object { $_ -replace "$prev", "$version" } | Out-File README-new.md
Move-Item -Force README-new.md README.md
Write-Host ""


Write-Host "[Building on Mac]"
bash src/scripts/mkmacdmg.sh --qt_path ~/Qt/5.11.1/clang_64/ --version $version
if (! $?) {
    Write-Output "[Error]"
    exit 1;
}
Write-Host ""


Write-Host "[Building Linux + Windows]"
Write-Host -NoNewline "Copying files.........."
# Cleanup some local files to aid copying
rm -rf lib/target/
ssh $server "rm -rf /tmp/zqwbuild"
ssh $server "mkdir /tmp/zqwbuild"
scp -r src/ singleapplication/ res/ lib/ ./yeclite.pro ./application.qrc ./LICENSE ./README.md ${server}:/tmp/zqwbuild/ | Out-Null
ssh $server "dos2unix -q /tmp/zqwbuild/src/scripts/mkrelease.sh" | Out-Null
ssh $server "dos2unix -q /tmp/zqwbuild/src/version.h"
Write-Host "[OK]"

ssh $server "cd /tmp/zqwbuild && APP_VERSION=$version PREV_VERSION=$prev bash src/scripts/mkrelease.sh"
if (!$?) {
    Write-Output "[Error]"
    exit 1;
}

New-Item artifacts -itemtype directory -Force         | Out-Null
scp    ${server}:/tmp/zqwbuild/artifacts/* artifacts/ | Out-Null
scp -r ${server}:/tmp/zqwbuild/release .              | Out-Null

# Finally, test to make sure all files exist
Write-Host -NoNewline "Checking Build........."
if (! (Test-Path ./artifacts/linux-binaries-YecLite-v$version.tar.gz) -or
    ! (Test-Path ./artifacts/linux-deb-YecLite-v$version.deb) -or
    ! (Test-Path ./artifacts/Windows-binaries-YecLite-v$version.zip) -or
    ! (Test-Path ./artifacts/macOS-YecLite-v$version.dmg)) {
        Write-Host "[Error]"
        exit 1;
    }
Write-Host "[OK]"

Write-Host -NoNewline "Signing Binaries......."
bash src/scripts/signbinaries.sh --version $version
Write-Host "[OK]"
