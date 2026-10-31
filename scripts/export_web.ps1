param(
	[string]$GodotPath = (Join-Path $env:USERPROFILE 'Desktop\Godot_v4.7.2-stable_win64.exe')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$webOutput = Join-Path $projectRoot 'build\web'
$htmlOutput = Join-Path $webOutput 'index.html'
$exportLog = Join-Path $projectRoot '.godot\web-export.log'
$splashSource = Join-Path $projectRoot 'assets\sprites\environments\Fairy-Tale-2D-Backgrounds__background__90a91df630cf.png'
$fontSource = Join-Path $projectRoot 'assets\fonts\Immortal.ttf'

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
	throw "No encuentro Godot en '$GodotPath'. Pasa la ruta correcta con -GodotPath."
}

New-Item -ItemType Directory -Path $webOutput -Force | Out-Null
$arguments = '--headless --path "' + $projectRoot + '" --export-release Web "' + $htmlOutput + '" --log-file "' + $exportLog + '"'
$godotProcess = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -Wait
if ($godotProcess.ExitCode -ne 0) {
	if (Test-Path -LiteralPath $exportLog) {
		Get-Content -LiteralPath $exportLog -Tail 60
	}
	throw "La exportación web de Godot terminó con código $($godotProcess.ExitCode)."
}

Copy-Item -LiteralPath $splashSource -Destination (Join-Path $webOutput 'valoria_splash.png') -Force
Copy-Item -LiteralPath $fontSource -Destination (Join-Path $webOutput 'Immortal.ttf') -Force
Get-ChildItem -LiteralPath $webOutput -Filter '*.tmp' -File | Remove-Item -Force

$pck = Get-Item -LiteralPath (Join-Path $webOutput 'index.pck')
$sizeMb = [math]::Round($pck.Length / 1MB, 1)
Write-Output "Exportación web de Godot lista: $webOutput ($sizeMb MB de datos del juego)."
Write-Output 'Sube el contenido de build/web a GitHub Pages o a otro hosting estático.'
