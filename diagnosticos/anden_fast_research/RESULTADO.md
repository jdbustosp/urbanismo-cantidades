# Investigacion de rendimiento: A/B/C y traslado directo .NET

**PROTOTIPOS NO APROBADOS PARA INSTALAR. Motor e instalacion siguen5.5.2.**

Agente: Codex. Equipo: BOG085CD119BDQN.
2026-09-14 04:39 America/Bogota. Base be4b704.
Pedido: investigar mas alternativas para generacion casi instantanea,
sin bloques anidados. La5.5.2 usa un bloque interno y NO satisface esta
restriccion incorporada en el pedido actual. No declarar problema terminado.

## Fuentes primarias consultadas

- [Bucles DXF de HATCH](https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-DC5215D6-E73F-4DFF-8BE9-01CA9610FAEE.htm)
- [HATCH: numero de bucles y paridad/islas](https://help.autodesk.com/cloudhelp/2023/ENU/AutoCAD-DXF/files/GUID-C6C71CED-CE0F-4184-82A5-07AD6241F15B.htm)
- [Comandos que clonan objetos, incluido BLOCK](https://help.autodesk.com/cloudhelp/2021/ENU/OARX-DevGuide/files/GUID-D3B9728E-E9EC-4C84-9EA5-0B027A6AFC09.htm)
- [Lineweight y zoom](https://help.autodesk.com/cloudhelp/2023/ENU/AutoCAD-Core/files/GUID-4B33ACD3-F6DD-4CB5-8C55-D6D0D7130905.htm)
- [Orden relativo en una llamada](https://help.autodesk.com/cloudhelp/2021/ENU/AutoCAD-ActiveX-Reference/files/GUID-AD2CA392-D4B5-4F0D-AE0B-3A376B396D31.htm)
- [AssumeOwnershipOf](https://help.autodesk.com/cloudhelp/2024/ENU/OARX-ManagedRefGuide/files/OARX-ManagedRefGuide-Autodesk_AutoCAD_DatabaseServices_BlockTableRecord_AssumeOwnershipOf_ObjectIdCollection.html)

## A: HATCH multibucle para la guia

Se prototiparon anillos de capsulas y juntas de1mm de espesor geometrico,
primero en un hatch por color, luego en lotes de256bucles de capsulas.
Sin bloques internos. Se preserva el contorno exterior de las capsulas,
pero el espesor geometrico NO equivale al lineweight: el lineweight de
pantalla no escala con el zoom, la franja geometrica si. Por ello no es
correcto prometer apariencia exactamente identica a cualquier zoom/ploteo.
Las juntas se agruparon por franja, no por256; falta ensayar otras divisiones.

**El prototipo NO paso.** El contador de hatches validados quedo en0 y las
cantidades cambiaron: guia188,10ML ->333,46ML. El constructor puede activar
su respaldo al fallar un helper; falta aislar la excepcion/etapa precisa del
HATCH. No asumir que10fallos de cantidades significan necesariamente un
error de formula del motor: esta corrida usa un generador experimental fallido.

| Prototipo | Longitud | Generar | Bloque | REGEN | Guardar | Total |
|---|---:|---:|---:|---:|---:|---:|
| Hatch unico, no aprobado | 188m | 41,875s | 40,016s | 0,500s | 0,281s | 82,672s |
| Lotes256, no aprobado | 188m | 7,235s | 6,421s | 0,141s | 0,484s | 14,281s |
| Lotes256, no aprobado | 800m | 23,406s | 28,032s | 0,172s | 0,375s | 51,985s |

La primera ronda se detuvo despues de observar mas de un minuto: el log
alcanzo a completar188m antes del cierre. Son tiempos del PROTOTIPO FALLIDO,
no mediciones certificadas de un hatch correcto ni prueba de que toda
estrategia multibucle sea inviable. No se instalara ni se presentara como mejora.

## B: emitir en orden

El orden actual no es accidental: rellenos, contornos, juntas, rellenos tactiles,
detalles, simbolos. El generador intercala fases por banda y luego reordena.
Eliminar el reordenamiento sin cambiar la emision puede tapar guia/toperol.
La medicion previa de Claude corresponde al19-21% del EMPAQUETADO, no del
tiempo total. No se midio un generador nuevo preordenado en esta ronda.
Alternativas: buffer por rol o clasificacion/orden relativo mediante una
llamada .NET. Son trabajo pendiente, no un ahorro30% total demostrado.

## C: reutilizar la lista previa a -BLOCK

Prueba minima REAL en Civil2023: objeto inicial handleF27, despues de-BLOCK
entget del original=nil, entidad dentro del bloque handleF2B.
**La lista anterior contiene originales borrados**, no las nuevas entidades.
Reutilizarla directamente es incorrecto con el camino actual. Tambien debe
corregirse la explicacion antigua del motor que describe-BLOCK como traslado:
desde el punto de vista de identidad fue clonado, aunque quite los originales.

## D: traslado directo nativo, sin clon ni bloque interno

Prototipo .NET FastPack.cs usando AssumeOwnershipOf, con verificacion de ruta
exacta del fixture. No abrir entidades ForWrite antes de esta llamada:
Autodesk advierte que puede terminar AutoCAD. Transaccion y bloque nuevos.
Se probo con motor5.5.1 plano, reemplazando SOLO el comando-BLOCK porFRPACK
y la enumeracion del bloque por la lista previa. No se cambio la generacion.

| Caso | Generar | Empaquetar | REGEN | Guardar | Total |
|---|---:|---:|---:|---:|---:|
| Plano5.5.1,188m | 5,062s | 6,344s | 0,063s | 0,343s | 11,812s |
| Traslado.NET,188m | 5,157s | 7,016s | 0,093s | 0,454s | 12,720s |
| Traslado.NET,800m | 25,219s | 36,750s | 0,281s | 0,688s | 62,938s |

Se verificaron bloque sinINSERTanidados, cero sueltas y cantidades iguales.
**No mejoro el tiempo.** La comprobacion combinada de propietario/DXF/XDATA
dio nil: no se aisló si hay diferencia geometrica real o un problema del
comparador (incluye serializacion de REGION). Por tanto tampoco esta aprobado.
El seguimiento corto para aislarlo no se ejecuto: ROT ya no publicaba el
fixture, el helper aborto sin enviar comandos a otro dibujo. No hubo reintento
ciego ni se toma ausencia de excepcion como equivalencia geometrica.

## Conclusion y siguiente experimento justificado

No hay una via casi instantanea demostrada. Tampoco hay motivo para sustituir
5.5.2 por alguno de estos prototipos. En el mismo laboratorio5.5.2 registro
10,157s total (incluye guardado), pero sigue anidando una franja y por eso no
es la solucion final bajo la nueva restriccion.

La siguiente investigacion debe atacar GENERACION y COM por pieza, no solo
el tipo de empaquetado: generar coordenadas en memoria y emitir el lote de
entidades planas dentro del bloque final desde .NET, con orden por roles y
una transaccion. Mantener geometria exacta y dejar .lsp como interfaz/orquestador.
Esto es una hipotesis arquitectonica, NO una mejora implementada ni un tiempo
garantizado. Primero medir una franja188m contra la emisionLISP, luego integrar
acabados/recortes/cantidades. Evitar otra reescritura general sin ese microbenchmark.

Una vista preliminar simplificada podria responder antes, pero NO equivale a
tener todo el anden detallado terminado. No ofrecerla como cumplimiento encubierto.

## Repeticion y estado

Laboratorio local Documents/URBANISMO/work/anden_fast_research. Civil2023
Metric real, instancias propias ocultas11216 y17976, ambas cerradas.
DWG limpio sintetico con coordenadas82800/102400, curvaS y3,5m de ancho.
No se intervino maestro, Excel, sesion del usuario ni instalacion productiva.
No hay observacion visual nueva del prototipo; requiere validacion de zoom y
ploteo si alguna variante deHATCH llega a pasar primero las pruebas numericas.

Archivos de investigacion en esta carpeta: native.lsp/prototype.lsp paraA,
FastPack.cs/ownership.lsp paraD y result.txt con fallos conservados. ParaD,
flat-d.lsp se obtiene de de02ad6:urbanismo_cantidades.lsp reemplazando
`(vl-catch-all-apply 'vl-cmdf (list "_.-BLOCK" block-name "0,0,0" ss ""))`
por `(vl-catch-all-apply 'FRPACK (list block-name ss))`, y dentro depackage-anden
`(urb:block-object-list block-definition)` por `objects` en el camino fast-ok.
CompilarFastPack.cs con cscFramework64v4, referencias acmgd/acdbmgd/accoremgd2023.
No distribuir esa DLL de prueba: restringida al fixture de este equipo.
No se cambia version ni se reinstala por una investigacion sin entrega funcional.
