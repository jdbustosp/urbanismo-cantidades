# El plugin estaba vinculado al libro EQUIVOCADO (2026-09-14)

Agente: Claude. Equipo: BOG085CD119BDQN.

## El problema
El usuario exporto desde Civil y "no le salio". El dialogo de Vinculacion
mostraba un libro en Google Drive, NO el de colsubsidio donde vive todo el
trabajo. Hay DOS archivos con el mismo nombre `urbanismo maipore.xlsx`.

## Comparacion medida de los dos libros

| | colsubsidio (correcto) | Google Drive (viejo) |
|---|---|---|
| ruta | `...\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\` | `...\Streaming de Google Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\` |
| actividades nivel 5 | **1.456** | **1.291** |
| total del presupuesto | **217.374.451.121** | 193.951.940.471 |
| filas GRP 45" | 2 | 0 |
| filas de zona verde 2.2.7 | 3 | 0 |
| recebo unificado | si | no (9 con el nombre viejo) |
| `Relleno con material seleccionado B-200` | 0 | 4 |
| hojas URB_AGG y Observaciones | si | **faltan** |

El dialogo del usuario decia "1291 actividades leidas": coincide EXACTO con
el de Google Drive. Ese numero es el indicador infalible de cual esta
vinculado -- 1291 = viejo, 1456 = correcto.

## Por que pasaba
`urb:ppto-config-read` AUTO-RESUELVE cuando la ruta guardada no responde:
busca el libro al lado del plano abierto (carpeta PADRE del DWG). Si se abre
un DWG de la carpeta de Google Drive, el plugin cae al libro viejo que esta
ahi. El archivo de configuracion en disco decia lo correcto, pero la SESION
abierta tenia la otra ruta en memoria.

## Que se hizo
Se reescribio `%APPDATA%\UrbanismoCantidades\ppto_libro.txt` apuntando al de
colsubsidio (respaldo en `ppto_libro.txt.bak_20260914`). NO se modifico
ningun libro: vincular solo cambia un puntero de texto.

## Verificado ejecutando el plugin (Civil 3D 2023 real, motor 5.5.4)
    V03 libro resuelto ......... colsubsidio
    V04 es el correcto ......... SI
    V05 abrir por COM .......... OK (1.563 ms)
    V06 TablaMemorias .......... OK   <- ahi se escriben las memorias
    V07 actividades leidas ..... 1456 <- el numero del libro correcto
    V08 hoja de presupuesto .... POR EJECUTAR

## Regla para no repetirlo
Trabajar SIEMPRE con el maestro de
`...\260915_ACTUALIZACION GENERAL PPTO\Memorias\URB_MASTER_GENERAL.dwg`.
Ese plano tiene el libro correcto en su carpeta padre, asi que aunque la
auto-resolucion se active, cae en el bueno. Abrir un DWG de la carpeta de
Google Drive vuelve a cambiar el vinculo al libro viejo.

## Aparte: por que el export parecia no hacer nada
No falla. Antes de tocar el libro recalcula todo: 27 s de carga del motor,
15 s de 2.036 puntos y **3 min 27 s de 1.153 tramos** (0 errores). Son mas
de 4 minutos sin senal visible. Medido el 2026-09-14.
