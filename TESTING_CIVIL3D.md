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

**Lección cara (2026-08-03, casi 30 min perdidos) — CORREGIDA:** la primera vez que pasó esto se sospechó de un perfil sucio por `Stop-Process -Force` (mismo patrón que Excel COM, ver [[excel-com-resiliency-dialog]]). Esa sospecha **era incorrecta** — la causa real, confirmada después con una captura de pantalla, fue otra (ver sección 3): la línea única del `.scr` superaba ~2000 caracteres y el procesador de scripts de AutoCAD la corta a mitad de camino, dejando la línea de comandos esperando paréntesis que nunca llegan (se ve como `((((_>` en el prompt). No tiene nada que ver con matar procesos. Reglas que sí siguen valiendo la pena:
- El polling debe ir en segundo plano (`run_in_background`), no en llamadas de `Bash` en primer plano con tope de ~3 min cada una — si el script no arrancó, cada intento fallido cuesta el máximo de espera posible antes de poder reaccionar.
- No reintentar el mismo `.scr` 3 veces a ciegas si no corrió — revisar primero si la ventana realmente abrió (`Get-Process acad | Select MainWindowTitle`) y si hay algo que diagnosticar (línea muy larga, diálogo de seguridad pendiente — ver sección 3) en vez de asumir mala suerte.

## 3. El truco del script `.scr`

Un `.scr` es una lista de "comandos" que AutoCAD ejecuta como si se tipearan en la línea de comandos.

**NO escribir la lógica de verificación como una sola línea `(progn ...)` gigante dentro del `.scr`.** Se intentó así al principio y falló de forma silenciosa y repetible: el procesador de scripts de AutoCAD **trunca/corta líneas de más de ~2000 caracteres** a mitad de camino. El síntoma es que la ventana abre normal, pero la línea de comandos queda esperando paréntesis que nunca van a llegar (se ve literalmente `((((_>` en el prompt de comandos) — no hay ningún mensaje de error, y el script nunca termina. Cuanto más larga la línea, peor: una de 1633 caracteres alcanzó a escribir una sola línea de resultado antes de cortarse; una de 2298 no escribió nada.

**Método correcto — `.scr` corto que carga un `.lsp` normal:**

1. Escribir toda la lógica de verificación en un archivo `.lsp` aparte, con saltos de línea normales (sin límite de longitud, porque lo lee el lector de LISP completo, no el procesador de scripts línea por línea).
2. El `.scr` en sí queda de solo 2 líneas:
   ```
   (load "C:/ruta/al/verify_helper.lsp")
   (command "_.QUIT" "_Y")
   ```
3. **El `.lsp` de ayuda debe vivir dentro de `BLOQUES PPTOS`** (o cualquier carpeta que Civil 3D ya tenga marcada como confiable), no en una carpeta temporal/scratchpad nueva. Un `.lsp` sin firmar en una carpeta que AutoCAD no reconoce dispara el diálogo "Security - Unsigned Executable File" (Load Once / Always Load / Do Not Load) — un diálogo de Windows que bloquea todo hasta que alguien le hace clic, y Claude no tiene control de escritorio para hacerlo. Si el usuario ve ese cartel, la respuesta correcta es **"Load Once"** (no "Always Load", innecesario para un script descartable). Borrar el `.lsp` de ayuda de `BLOQUES PPTOS` al terminar (es un archivo temporal, no parte del proyecto).
4. Dentro del `.lsp` de ayuda: abrir el archivo de resultados con `open ... "w"`, envolver cada paso riesgoso en `(vl-catch-all-apply 'funcion (list args))` (si no se envuelve, un error sin capturar corta el resto del script Y hace que el `.scr` pase directo a `QUIT` — la ventana "se cierra sola" sin dejar rastro del motivo), escribir cada resultado con `write-line`, cerrar con `close`.

Ejemplo real usado en este repo (`.lsp` de ayuda, no el `.scr`):

```lisp
(setq *st-f* (open "C:/ruta/resultado.txt" "w"))
(defun st-log (msg) (write-line msg *st-f*) (princ))
(setq *st-load* (vl-catch-all-apply 'load (list "D:/ruta/urbanismo_cantidades.lsp")))
(st-log (if (vl-catch-all-error-p *st-load*) (strcat "LOAD-ERROR: " (vl-catch-all-error-message *st-load*)) "LOAD-OK"))
(setq *st-r* (vl-catch-all-apply 'mp:pvc-trench-width (list 8.0 2.0)))
(st-log (strcat "resultado: " (vl-princ-to-string *st-r*)))
(st-log "DONE")
(close *st-f*)
(princ)
```

Notas:
- Usa **rutas con `/` en vez de `\`** dentro de los strings de Lisp — Windows las acepta igual y evita pelear con el escape de backslash.
- `LOAD-OK` por sí solo ya es una prueba fuerte: si cualquier `defun` del archivo tiene un paréntesis mal cerrado, el `(load ...)` falla y se captura como `LOAD-ERROR`.
- **AutoLISP NO tiene `fboundp`** (es de Common Lisp, no está en el dialecto de AutoCAD) — usarlo revienta con `no function definition: FBOUNDP`. Para chequear si una función quedó definida tras el `load`, lo más simple es directamente intentar llamarla envuelta en `vl-catch-all-apply` y revisar si el error es "no function definition" vs otra cosa, o simplemente confiar en que si `LOAD-OK` salió, todo `defun` del archivo se registró (un `defun` nunca falla silenciosamente si el archivo cargó completo).
- Esto **solo sirve para funciones que no abren un diálogo ni esperan un clic** (`load_dialog`/`start_dialog`, o un `(command "_.PLINE")` esperando picks). Para esas, la única prueba real es que el usuario las use a mano en su sesión.
- Para verificar una función que sí escribe un archivo de verdad (como las que generan un `.dcl`), se puede leer ese archivo después con la herramienta `Read` normal y compararlo contra lo que el código viejo hubiera escrito.
- Como respaldo rápido que no depende de lanzar Civil 3D en absoluto: un chequeo de balance de paréntesis de todo el archivo (recorrer el texto carácter por carácter, respetando strings entre comillas y comentarios `;`, sumando `(` y restando `)`) detecta la mayoría de errores de sintaxis en segundos. Útil como primera pasada antes de gastar tiempo en el arranque de Civil 3D. Ojo: esta máquina no tiene Python instalado de verdad (solo el stub de Microsoft Store) — escribirlo en PowerShell si hace falta.

## 3b. Política de PDFs de verificación (2026-08-11, pedido del usuario)

La verificación debe ser NUMÉRICA primero (conteos de entidades, censos de hatches por color/patrón, atributos, coordenadas, matemática a mano) — eso no genera archivos. El ploteo a PDF se reserva SOLO para cuando hay que VER una textura o composición, y esos PDFs van SIEMPRE a la carpeta temporal de la sesión de Claude (scratchpad), NUNCA a la carpeta del repo ni a Drive. Los `_tmp_*.pdf` que sesiones anteriores dejaron en BLOQUES PPTOS se borraron el 2026-08-11 — no repetir ese patrón.

## 3c. Metodología v2 — absorbida de las sesiones Codex del 2026-08-12/13 (v4.21.1 → v4.23.4)

El usuario trabajó estas versiones con Codex (OpenAI) y pidió expresamente adoptar su metodología, que resultó más precisa. Reglas que se suman a las anteriores (y las refinan):

1. **Laboratorio persistente por tema**: cada verificación vive en `C:\Users\juanbusper\Documents\URBANISMO\work\<tema>\` (carpeta LOCAL, fuera de Drive, sobrevive entre sesiones) con exactamente: `verify_<tema>.lsp` (el harness), `verify_<tema>.scr` (2 líneas: load + QUIT), y `verify_<tema>_result.txt` (el resultado, escrito por el harness en la MISMA carpeta). Ver ejemplo real completo: `work\curved_gap_fix\verify_gap_v4211.lsp`.
2. **Asserts por INVARIANTES, nunca por inspección visual**: el harness afirma condiciones exactas y escribe `ok T/nil` por caso — conteos por rol (`urb:generated-role`) y por clase VLA (`AcDbRegion`/`AcDbHatch`), igualdad de conteos región=hatch (cada región DEBE tener su relleno), e **igualdad exacta de áreas** (`(equal source-area base-area 1e-6)`: el área del contorno de entrada contra el área realmente cubierta). Un booleano que "no lanza excepción" NO es éxito — la 4.21.0 falló justo por contar como válida una banda con región degenerada o hatch fallido.
3. **Caso de peor escenario deliberado**: el dato de prueba se construye para forzar el bug — p.ej. un anillo con radio interior 5.40 que coincide EXACTO con una junta del patrón 0.80/1.00, forzando la tangencia que originaba el hueco. No probar solo el caso feliz.
4. **Operaciones geométricas transaccionales**: si un paso de una cadena (booleano → región → hatch) falla, se borra TODO lo parcial y se reintenta con parámetro más agresivo (solapes progresivos 0/0.5/1.5/4/10 mm); y una capa base de cobertura total (`BASE_FILL`) garantiza que ningún fallo residual sea visible.
5. **DLLs con nombre versionado** (`UrbCantRibbon2023_v4234.dll` + `PackageContents.xml` apuntando al nombre nuevo): esquiva el bloqueo de archivo de la sesión abierta — la DLL vieja sigue cargada, la nueva carga en el próximo arranque sin exigir cerrar todo para copiar.
6. **Al INICIO de cada sesión de trabajo**: `git status` + `git log origin/main..HEAD` — las sesiones de Codex dejaron 9 commits sin push (se subieron el 2026-08-13); con el flujo multi-computador un commit local sin push es una pérdida esperando pasar.
7. Sin PDFs (refuerza la política 3b): todo lo anterior es numérico. Codex no generó ni un PDF en ~2.900 líneas cambiadas.

## 3d. Protocolo v3 (2026-08-13) — reglas VINCULANTES antes de decir "arreglado"

Diseñado a pedido del usuario tras comparar resultados: con el ciclo viejo (hipótesis → parche → verificar que el parche corre) el mismo bug volvió 2-3 veces; con este ciclo se arregla una vez. **Ninguna respuesta de "quedó corregido" es válida si no pasó por los 5 pasos:**

1. **Estado antes que diagnóstico.** Confirmar QUÉ versión produjo la evidencia del usuario: el log/pantallazo debe mostrar mensajes de la versión actual (los prompts nuevos delatan la versión); verificar bundle instalado = repo; `git status` + `git log origin/main..HEAD`. Si la sesión del usuario es vieja, la única instrucción válida es reiniciar — no parchar fantasmas (pasó: una ronda entera diagnosticando contra una sesión desactualizada).
2. **Reproducir EL flujo exacto del usuario, no un análogo.** Mismo modo del diálogo, mismo tipo de clic, mismo estado de datos (ej: vía SIN movimiento calculado). El log del usuario dice línea por línea qué rama corrió — reconstruirla. Si el síntoma no se reproduce, decirlo ("no reproducible, necesito X") en vez de parchar la causa plausible. Regla dura: **el harness debe FALLAR contra el código viejo** (cargar la versión anterior con `git show <sha>:archivo` en una corrida aparte si hay duda) — un test que no detecta el bug original no valida nada.
3. **Arreglar la CLASE, no la instancia.** Preferir diseños que hacen el síntoma IMPOSIBLE (capa base de cobertura, operación transaccional que borra lo parcial, cascada de recuperación) sobre reductores de probabilidad (nudges, reintentos sueltos). Si el arreglo depende de un estado de datos (ej: "la vía debe tener rasante"), el camino de falla debe EXPLICARSE solo en el prompt — cada falla silenciosa convertida en mensaje convierte la próxima ronda del usuario en un reporte preciso en vez de un misterio.
4. **Validar con invariantes + peor caso, en UNA sola corrida headless.** Invariante = condición que solo puede pasar si el bug desapareció de raíz (conservación de área 1e-6, conteos 1:1 región/hatch, valor exacto calculado a mano por fuera). Peor caso construido a propósito + caso feliz + el flujo del usuario del paso 2, todos como checks del mismo harness, con resumen `TODO-OK/HAY-FALLOS`.
5. **Entregar con evidencia y con criterio de falsación.** La respuesta dice: mecanismo de la falla, números del invariante que pasó, qué debe hacer el usuario (reiniciar/recrear), y qué observación lo refutaría ("si después de X sigues viendo Y, entonces es Z").

**Economía de tokens (el ahorro real está en no repetir rondas, pero además):**
- Librería común `C:\Users\juanbusper\Documents\URBANISMO\work\_lib\verify_lib.lsp` (constructores de datos sintéticos: rect, anillo curvo de peor caso, corredor curvo, vía completa con rasante; asserts: `vlib:check`, conservación de área, conteos por rol, detector de huecos). Un harness nuevo = ~20-40 líneas de asserts, no 100+ reescritas.
- `Documents\URBANISMO\work\...` es RUTA CONFIABLE (la agrega `urb:ensure-trusted-path` en cada carga del plugin desde v4.23.5) — los harnesses corren desde su carpeta sin diálogo de seguridad y sin copiar nada al bundle.
- Una sola corrida headless por ronda con TODOS los checks batcheados; releer archivos grandes solo por rangos/grep dirigido; si un problema REAPARECE una segunda vez, detener el ciclo de parches y leer el subsistema completo — la reincidencia significa que el modelo de la causa está mal, no el parche.

## 4. Lanzar y esperar el resultado

**ADVERTENCIA (2026-08-11): lanzar SIEMPRE desde PowerShell, jamás desde Git Bash.** Bash/MSYS convierte el argumento `/b` en una ruta (`C:/Program Files/Git/b`); AutoCAD lo toma como un dibujo a abrir, muestra un diálogo modal "Cannot find the specified drawing file" (que Claude no puede ver ni cerrar) y la instancia queda eterna en la pantalla [Start]. Este fue el verdadero origen de los "cuelgues" del 2026-08-04 y 2026-08-11 — no era contención de licencia con la sesión abierta del usuario, como se creyó al principio.

```powershell
$scr = "C:\ruta\al\script.scr"
$proc = Start-Process -FilePath "<acad.exe encontrado en paso 1>" `
  -ArgumentList @('/ld', '"<ruta AecBase.dbx>"', '/p', '"<<perfil>>"', '/product', 'C3D', '/language', 'en-US', '/b', "`"$scr`"") `
  -PassThru
$proc.Id   # guardar este PID
```

Desde Bash, hacer polling del archivo de resultado (no hay forma de que te "avisen" cuando termina). **Lanzar este polling con `run_in_background: true`** en vez de una llamada de `Bash` en primer plano — así no se bloquea el turno esperando, y si el `.scr` no arrancó (ver lección arriba) uno se entera sin haber gastado el tope de espera de una llamada en primer plano:

```bash
for i in $(seq 1 24); do
  if [ -f "$RESULT" ] && grep -q "DONE" "$RESULT" 2>/dev/null; then break; fi
  sleep 5
done
cat "$RESULT"
```

El arranque de Civil 3D es lento y variable (40 segundos a más de 2 minutos según la carga de la máquina). No asumir que si el archivo está vacío a los 10 segundos algo falló — recién a los 3-4 minutos sin ningún avance vale la pena sospechar que se colgó (y ahí aplica la lección de arriba: sospechar del perfil, no relanzar igual).

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
