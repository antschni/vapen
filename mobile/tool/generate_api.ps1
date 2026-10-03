# Regenerates packages/vapen_api from api/openapi.yaml using OpenAPI Generator.
# Requires: Java, openapi-generator-cli on PATH (or docker).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$OpenApi = Join-Path $Root "api\openapi.yaml"
$Out = Join-Path $Root "mobile\packages\vapen_api_gen"
if (Get-Command openapi-generator-cli -ErrorAction SilentlyContinue) {
  if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
  openapi-generator-cli generate `
    -i $OpenApi `
    -g dart-dio `
    -o $Out `
    --additional-properties=pubName=vapen_api_gen,serializationLibrary=json_serializable
  Write-Host "Generated into $Out — merge into packages/vapen_api as needed."
} else {
  Write-Host "openapi-generator-cli not found. Hand-maintained client is in packages/vapen_api."
  Write-Host "Install: https://openapi-generator.tech/docs/installation"
}
