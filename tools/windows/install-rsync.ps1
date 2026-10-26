$ErrorActionPreference='Stop'
$taskPackages=@(
    @{Name='rsync-3.5.1-2-x86_64.pkg.tar.zst';Hash='CBA52E41D16F9873324FCF09853619964DA87BC1CE116781A5449C968D4FFECC'},
    @{Name='libxxhash-0.8.4-1-x86_64.pkg.tar.zst';Hash='BA784AD117626401CD5D3EC0CF70399F9DE72A63755F96C28FA2032303F9C330'},
    @{Name='popt-1.19-1-x86_64.pkg.tar.zst';Hash='B402BD1D03815C5E28B7AB415D8E20F487EFF2460AE0271A99674EEB0D77194F'}
)
foreach ($taskPackage in $taskPackages) {
    $taskArchive=Join-Path ([IO.Path]::GetTempPath()) $taskPackage.Name
    Invoke-WebRequest -UseBasicParsing -Uri "https://repo.msys2.org/msys/x86_64/$($taskPackage.Name)" -OutFile $taskArchive
    if ((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash -ne $taskPackage.Hash) { throw 'Package checksum mismatch' }
    tar -xf $taskArchive -C $PSScriptRoot usr/bin
    if ($LASTEXITCODE -ne 0) { throw 'Package extraction failed' }
}
Write-Output 'rsync installed locally; run scripts/host-tools.ps1 using Git for Windows'
