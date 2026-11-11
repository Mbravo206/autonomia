# Genera los audios de Cocina y Organizacion con la misma voz del Medidor:
# Microsoft Sabina Desktop (espanol de Mexico), velocidad -1, WAV de 22050 Hz mono 16 bits.
# Los textos estan en textos.json (carpeta destino -> nombre del archivo -> texto).
#
# Uso, desde la carpeta raiz del repo:
#   powershell -ExecutionPolicy Bypass -File voz\generar_voces.ps1
# Solo funciona en Windows con la voz Sabina instalada (viene con Windows en espanol).

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

$VOZ = "Microsoft Sabina Desktop"
$VELOCIDAD = -1

$raiz = Split-Path -Parent $PSScriptRoot
$textos = Get-Content (Join-Path $PSScriptRoot "textos.json") -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($carpeta in $textos.PSObject.Properties) {
  $destino = Join-Path $raiz $carpeta.Name
  New-Item -ItemType Directory -Force $destino | Out-Null
  foreach ($clip in $carpeta.Value.PSObject.Properties) {
    $archivo = Join-Path $destino ($clip.Name + ".wav")
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $s.SelectVoice($VOZ)
    $s.Rate = $VELOCIDAD
    $s.SetOutputToWaveFile($archivo)
    $s.Speak($clip.Value)
    $s.Dispose()
    Write-Output ("{0}/{1}.wav" -f $carpeta.Name, $clip.Name)
  }
}
