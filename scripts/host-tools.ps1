param(
    [string]$Command = 'bash scripts/deploy.sh',
    [string]$VmIp = '192.168.56.101'
)
# Linux utilities for the Windows host, using the existing Docker Desktop.
$ErrorActionPreference = 'Stop'
$taskRepoRoot = Split-Path -Parent $PSScriptRoot
$taskKey = Join-Path $env:USERPROFILE '.ssh/devops_vm'
$taskKnownHosts = Join-Path $env:USERPROFILE '.ssh/known_hosts'
$taskCertificate = Join-Path $env:USERPROFILE 'devops.crt'
foreach ($taskFile in @($taskKey,$taskKnownHosts)) {
    if (-not (Test-Path -LiteralPath $taskFile -PathType Leaf)) { throw "Missing file: $taskFile" }
}
$taskImage = 'devops-host-tools:pr5-7'
$taskImageId = docker image ls --quiet $taskImage
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not available' }
if (-not $taskImageId) {
    docker build -t $taskImage -f (Join-Path $taskRepoRoot 'tools/host/Dockerfile') (Join-Path $taskRepoRoot 'tools/host')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot build host tools image' }
}
$taskArgs = @('run','--rm','--add-host',"devops.local:$VmIp",
    '--mount',"type=bind,source=$taskRepoRoot,target=/workspace",
    '--mount',"type=bind,source=$taskKey,target=/run/client-key,readonly",
    '--mount',"type=bind,source=$taskKnownHosts,target=/run/client-hosts,readonly",
    '--mount',"type=bind,source=$(Join-Path $taskRepoRoot 'tools/host/entrypoint.sh'),target=/run/host-runner.sh,readonly",
    '--tmpfs','/root/.ssh:mode=0700')
if (Test-Path -LiteralPath $taskCertificate -PathType Leaf) {
    $taskArgs += @('--mount',"type=bind,source=$taskCertificate,target=/run/client-cert,readonly")
}
$taskArgs += @($taskImage,'bash','/run/host-runner.sh',$Command)
docker @taskArgs
exit $LASTEXITCODE
