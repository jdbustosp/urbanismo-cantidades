# Cómo se prueba este .lsp contra Civil 3D real (sin control de escritorio)

Claude Code no tiene una herramienta de "computer use" para el escritorio de Windows — solo controla un navegador web embebido. No puede hacer clic en un diálogo de AutoCAD ni dibujar una polilínea a mano. Lo que sí puede hacer es lanzar Civil 3D real por línea de comandos y automatizarlo con un **script `.scr`** que corre código AutoLISP sin necesidad de interacción, capturando los resultados en un archivo de texto. Esto sirve para detectar errores de sintaxis y verificar funciones puras (que no abren diálogos ni esperan clics del usuario) contra la aplicación real, no solo con revisión de código.

Esta guía es para repetir el proceso en otra máquina o en otra sesión de Claude Code.

## 1. Encontrar la instalación de Civil 3D

Civil 3D comparte el `acad.exe` de AutoCAD; lo que lo diferencia es con qué argumentos se lanza (perfil + módulos `.dbx`). No asumas la ruta — bloquéala con estos pasos:

```powershell
# Carpetas de Autodesk instaladas
Get-ChildItem 'C:\Program Files\Autodesk' -Directory

# Confirmar versiones de Civil 3D instaladas y su carpeta real
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -match 'Civil 3D' } |
  Select-Object DisplayName, InstallLocation

# Los argumentos EXACTOS de lanzamiento (perfil, /product, /ld) están en el
# acceso directo del menú inicio, no hay que adivinarlos:
Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -Filter '*.lnk' |
  Where-Object { $_.Name -match 'Civil' }

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut('<ruta al .lnk encontrado arriba>')
$sc.TargetPath   # ej: C:\Program Files\Autodesk\AutoCAD 2025\acad.exe
$sc.Arguments    # ej: /ld "...\AecBase.dbx" /p "<<C3D_Metric>>" /product C3D /language en-US
```

Si hay varias versiones instaladas, pregúntale al usuario cuál usa — no lo asumas (aquí había 2025 y 2026 a la vez).

## 2. Antes de lanzar nada: revisar si ya hay una sesión abierta

```powershell
Get-Process acad -ErrorAction SilentlyContinue | Select-Object Id, MainWindowTitle, Responding
```

**Importante**: el usuario puede tener su propio dibujo de trabajo abierto en paralelo (pasó en esta sesión: `URB_MASTER_GENERAL.dwg` corriendo mientras se hacían pruebas). Nunca uses `Stop-Process` sobre un PID que no lanzaste tú mismo — guarda el PID que devuelve `Start-Process` y solo mata ese.

Con dos instancias de Civil 3D corriendo a la vez (la del usuario + la de prueba) se observó que el script `/b` a veces no arranca (la ventana abre normal pero el `.scr` nunca se ejecuta, sin ningún mensaje de error). Si eso pasa, no insistir mucho — matar la instancia de prueba (nunca la del usuario) y aceptar que la verificación automática tiene un límite en ese escenario.

## 3. El truco del script `.scr`

Un `.scr` es una lista de "comandos" que AutoCAD ejecuta como si se tipearan en la línea de comandos. Acepta expresiones AutoLISP completas con tal de que quepan balanceadas — lo más simple es escribir **una sola línea `(progn ...)` gigante** que:

1. Abre un archivo de resultados con `open ... "w"`.
2. Envuelve cada paso riesgoso en `(vl-catch-all-apply 'funcion (list args))` para que un error no aborte todo el script silenciosamente (si no se envuelve, un error deja el resto del `.scr` sin ejecutar y sin ningún rastro).
3. Escribe cada resultado con `write-line` al archivo.
4. Cierra el archivo con `close`.
5. En una segunda línea del `.scr`, `(command "_.QUIT" "_Y")` para cerrar sin guardar.

Ejemplo real usado en este repo (cargar el archivo y probar 3 funciones puras):

```lisp
(progn
  (setq *st-f* (open "C:/ruta/resultado.txt" "w"))
  (setq *st-load* (vl-catch-all-apply 'load (list "D:/ruta/urbanismo_cantidades.lsp")))
  (write-line (if (vl-catch-all-error-p *st-load*) (strcat "LOAD-ERROR: " (vl-catch-all-error-message *st-load*)) "LOAD-OK") *st-f*)
  (setq *st-r* (vl-catch-all-apply 'mp:pvc-trench-width (list 8.0 2.0)))
  (write-line (strcat "resultado: " (vl-princ-to-string *st-r*)) *st-f*)
  (close *st-f*)
  (princ)
)
(command "_.QUIT" "_Y")
```

Notas:
- Usa **rutas con `/` en vez de `\`** dentro de los strings de Lisp — Windows las acepta igual y evita pelear con el escape de backslash dentro de un string ya escapado en el `.scr`.
- `LOAD-OK` por sí solo ya es una prueba fuerte: si cualquier `defun` del archivo tiene un paréntesis mal cerrado, el `(load ...)` falla y se captura como `LOAD-ERROR`.
- Esto **solo sirve para funciones que no abren un diálogo ni esperan un clic** (`load_dialog`/`start_dialog`, o un `(command "_.PLINE")` esperando picks). Para esas, la única prueba real es que el usuario las use a mano en su sesión.
- Para verificar una función que sí escribe un archivo de verdad (como las que generan un `.dcl`), se puede leer ese archivo después con la herramienta `Read` normal y compararlo contra lo que el código viejo hubiera escrito.

## 4. Lanzar y esperar el resultado

```powershell
$scr = "C:\ruta\al\script.scr"
$proc = Start-Process -FilePath "<acad.exe encontrado en paso 1>" `
  -ArgumentList @('/ld', '"<ruta AecBase.dbx>"', '/p', '"<<perfil>>"', '/product', 'C3D', '/language', 'en-US', '/b', "`"$scr`"") `
  -PassThru
$proc.Id   # guardar este PID
```

Desde Bash, hacer polling del archivo de resultado (no hay forma de que te "avisen" cuando termina):

```bash
for i in $(seq 1 24); do
  if [ -f "$RESULT" ] && grep -q "DONE" "$RESULT" 2>/dev/null; then break; fi
  sleep 5
done
cat "$RESULT"
```

El arranque de Civil 3D es lento y variable (40 segundos a más de 2 minutos según la carga de la máquina). No asumir que si el archivo está vacío a los 10 segundos algo falló — recién a los 3-4 minutos sin ningún avance vale la pena sospechar que se colgó.

## 5. Limpiar al final

Matar solo el PID propio, nunca `Get-Process acad | Stop-Process` a ciegas:

```powershell
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
```

## Qué se verificó con este método en este repo

- Que el archivo completo carga sin errores de sintaxis tras cada cambio (`LOAD-OK`).
- Que las 3 funciones de generación de diálogo `.dcl` (después de unificarlas en un helper genérico) siguen escribiendo un archivo `.dcl` idéntico línea por línea al que escribía el código original.
- Funciones puras nuevas del cálculo de movimiento de tierras (tabla de anchos, integración de volumen) con datos sintéticos, incluyendo el caso "sin superficie" para confirmar que degrada bien sin explotar.

## Qué NO se puede verificar así (necesita al usuario, a mano, en su sesión)

- Que los diálogos DCL se ven y comportan bien (combos llenos, valores correctos).
- Que `urb:draw-polyline-interactive` funciona al dibujar de verdad con el mouse.
- Que el muestreo de superficie (`mp:tramo-depth-profile`) da números sensatos contra la superficie `SUP_TN` real de un proyecto — para eso hace falta un dibujo con superficie y tramos reales, que Claude no tiene forma de abrir por su cuenta salvo que sea la sesión que el propio usuario ya tiene abierta.
