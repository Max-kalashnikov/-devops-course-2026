$ErrorActionPreference='Stop'
$taskPackages=@(
    @{Name='rsync-3.5.1-2-x86_64.pkg.tar.zst';Hash='CBA52E41D16F9873324FCF09853619964DA87BC1CE116781A5449C968D4FFECC'},
    @{Name='libxxhash-0.8.4-1-x86_64.pkg.tar.zst';Hash='BA784AD117626401CD5D3EC0CF70399F9DE72A63755F96C28FA2032303F9C330'},
    @{Name='popt-1.19-1-x86_64.pkg.tar.zst';Hash='B402BD1D03815C5E28B7AB415D8E20F487EFF2460AE0271A99674EEB0D77194F'},
    @{Name='curl-8.23.0-1-x86_64.pkg.tar.zst';Hash='6F21E0187E3F309199E01F729D415CCFEB304CC9F8A27365C8AA9C216351022E'},
    @{Name='libcurl-8.23.0-1-x86_64.pkg.tar.zst';Hash='3034AAE7FB58E129C7AF62A7E7D2AE12E0A3475A5310D7FDAD38FE9A3C672C9D'},
    @{Name='libnghttp2-1.70.0-1-x86_64.pkg.tar.zst';Hash='9B3443FF1B26A3ECE9394409EFCA60F3AC8EEE94309E5BE1E6B05706F3386110'},
    @{Name='libnghttp3-1.18.0-1-x86_64.pkg.tar.zst';Hash='45FDD8613FA1DA08F6C0504377194497FEA540ED1FEC438BC557736459040669'},
    @{Name='libngtcp2-1.25.0-1-x86_64.pkg.tar.zst';Hash='A4C389078632E64AC2B320473651E80D44C97F9FED7A746A232D95B400B14FE8'},
    @{Name='libssh2-1.11.1-1-x86_64.pkg.tar.zst';Hash='F79883AF85A2BB4778E1352C0B7EA27737A05E4110EF14461F0A842A40FF893D'},
    @{Name='libopenssl-3.6.5-1-x86_64.pkg.tar.zst';Hash='05F6CC946F0DDE3AECC3632007FA1D874E40720226117B750327BC2A01846325'},
    @{Name='brotli-1.2.1-1-x86_64.pkg.tar.zst';Hash='0CFD703CBE467C6B645444C5D1EC03F423DCACA241BB99B5BAAB61D70447CEFD'}
)
foreach ($taskPackage in $taskPackages) {
    $taskArchive=Join-Path ([IO.Path]::GetTempPath()) $taskPackage.Name
    Invoke-WebRequest -UseBasicParsing -Uri "https://repo.msys2.org/msys/x86_64/$($taskPackage.Name)" -OutFile $taskArchive
    if ((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash -ne $taskPackage.Hash) { throw 'Package checksum mismatch' }
    tar -xf $taskArchive -C $PSScriptRoot usr/bin
    if ($LASTEXITCODE -ne 0) { throw 'Package extraction failed' }
}
Write-Output 'rsync installed locally; run scripts/host-tools.ps1 using Git for Windows'

# Keep TLS verification intact while avoiding host interception of curl.exe.
Copy-Item (Join-Path $PSScriptRoot 'usr/bin/curl.exe') (Join-Path $PSScriptRoot 'usr/bin/devops-http.exe') -Force
Copy-Item (Join-Path $PSScriptRoot 'curl-wrapper.sh') (Join-Path $PSScriptRoot 'usr/bin/curl') -Force
