# Run rule-engine and validation checks with Node.js when no HarmonyOS device is available.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-logic.ps1
#
# Requires TypeScript and Node bundled with DevEco Studio.
# Override with DEVECO_TSC and DEVECO_NODE if needed.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$verify = Join-Path $root '.verify'

if (Test-Path $verify) {
  Remove-Item $verify -Recurse -Force
}
New-Item -ItemType Directory -Force -Path `
  (Join-Path $verify 'model'), `
  (Join-Path $verify 'common'), `
  (Join-Path $verify 'mock'), `
  (Join-Path $verify 'engine') | Out-Null

$pairs = @(
  @('entry\src\main\ets\model\Types.ets', 'model\Types.ts'),
  @('entry\src\main\ets\common\Constants.ets', 'common\Constants.ts'),
  @('entry\src\main\ets\common\Labels.ets', 'common\Labels.ts'),
  @('entry\src\main\ets\common\Clone.ets', 'common\Clone.ts'),
  @('entry\src\main\ets\common\Validation.ets', 'common\Validation.ts'),
  @('entry\src\main\ets\mock\MockData.ets', 'mock\MockData.ts'),
  @('entry\src\main\ets\engine\RuleEngine.ets', 'engine\RuleEngine.ts')
)
foreach ($pair in $pairs) {
  Copy-Item (Join-Path $root $pair[0]) (Join-Path $verify $pair[1]) -Force
}
Copy-Item (Join-Path $PSScriptRoot 'logic-tests.ts') (Join-Path $verify 'verify.ts') -Force

$tsconfig = @'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "lib": ["ES2020", "DOM"],
    "rootDir": ".",
    "outDir": "out",
    "strict": false,
    "skipLibCheck": true,
    "noEmitOnError": true
  },
  "include": ["**/*.ts"]
}
'@
Set-Content -Path (Join-Path $verify 'tsconfig.json') -Value $tsconfig -Encoding ASCII

$tsc = $env:DEVECO_TSC
if ([string]::IsNullOrWhiteSpace($tsc)) {
  $tsc = 'D:\DevEcoStudio\DevEco Studio\tools\hvigor\hvigor\node_modules\typescript\lib\tsc.js'
}
if (-not (Test-Path $tsc)) {
  throw "tsc not found: $tsc. Set DEVECO_TSC to the TypeScript tsc.js path."
}

$node = $env:DEVECO_NODE
if ([string]::IsNullOrWhiteSpace($node)) {
  $node = 'D:\DevEcoStudio\DevEco Studio\tools\node\node.exe'
}
if (-not (Test-Path $node)) {
  $node = (Get-Command node -ErrorAction Stop).Source
}

Push-Location $verify
try {
  & $node $tsc -p tsconfig.json
  if ($LASTEXITCODE -ne 0) {
    throw "TypeScript compilation failed with exit code $LASTEXITCODE"
  }
  & $node (Join-Path $verify 'out\verify.js')
  if ($LASTEXITCODE -ne 0) {
    throw "Logic tests failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
