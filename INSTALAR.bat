@echo off
REM ============================================================
REM  Instalador de Urbanismo Cantidades - DOBLE CLIC y listo.
REM  Delega en instalar_bundle.ps1 (copia el plugin, limpia
REM  interfaces viejas y agrega la ruta confiable para que no
REM  salga el dialogo de seguridad). Correrlo de nuevo = actualizar.
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_bundle.ps1"
if errorlevel 1 (
  echo.
  echo ERROR: la instalacion fallo. Cierre AutoCAD e intente de nuevo.
)
echo.
pause
