@echo off
REM ============================================================
REM  Instalador de Urbanismo Cantidades - DOBLE CLIC y listo.
REM  Copia el plugin a la carpeta de plugins de Autodesk; al
REM  reiniciar AutoCAD/Civil 3D carga solo (URBANISMO y EDITAR).
REM  Correrlo de nuevo = actualizar a la version actual del repo.
REM ============================================================
setlocal
set "DEST=%APPDATA%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle"

if not exist "%~dp0urbanismo_cantidades.lsp" (
  echo ERROR: no se encontro urbanismo_cantidades.lsp junto a este instalador.
  echo Este archivo debe estar dentro de la carpeta BLOQUES PPTOS del repo.
  pause
  exit /b 1
)
if not exist "%~dp0bundle\PackageContents.xml" (
  echo ERROR: no se encontro bundle\PackageContents.xml en el repo.
  pause
  exit /b 1
)

mkdir "%DEST%\Contents" 2>nul
copy /y "%~dp0bundle\PackageContents.xml" "%DEST%\PackageContents.xml" >nul
if errorlevel 1 goto :fallo
copy /y "%~dp0urbanismo_cantidades.lsp" "%DEST%\Contents\urbanismo_cantidades.lsp" >nul
if errorlevel 1 goto :fallo

echo.
echo   Plugin instalado / actualizado en:
echo     %DEST%
echo.
echo   Reinicie AutoCAD / Civil 3D y ya quedan los comandos
echo   URBANISMO y EDITAR cargados automaticamente.
echo.
pause
exit /b 0

:fallo
echo.
echo ERROR: no se pudo copiar. Cierre AutoCAD e intente de nuevo.
pause
exit /b 1
