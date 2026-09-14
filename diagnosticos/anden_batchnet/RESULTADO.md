# Prueba: guia plana por lote .NET directamente en el bloque final

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha/hora: 2026-09-14 06:21 America/Bogota. Base f998afd, motor5.5.2.
**Estado: prototipo probado, NO integrado ni instalado en produccion.**

## Resultado principal

La emision por lote funciona SIN bloques internos y conserva las entidades
graficas y las cantidades de los casos probados. No demostro generacion casi
instantanea. La mejora de188m no fue estable entre corridas; en800m se midio
12,3% menos tiempo de generar+empaquetar+regenerar en la corrida completa.

No se modifico el DWG maestro, ningun Excel ni la instalacion5.5.2 del usuario.
Se uso Civil3D2023 Metric real, instancias propias ocultas, fixture local vacio,
curvaS con dos arcos, ancho3,5m, coordenadas82800/102400 y formato20x20.

## Implementacion ensayada

1. El .lsp sigue calculando TODAS las coordenadas, orientaciones y recortes.
2. Las capsulas y juntas aceptadas se almacenan en memoria, con doubles
   originales: no texto redondeado, hatch sustitutivo ni simbolos simplificados.
3. Se empaquetan los demas componentes con el mecanismo existente.
4. `BNAPPEND` recibe un lote y emite LINE/LWPOLYLINE directamente en la
   definicion del bloque FINAL con AppendEntity y una transaccion.NET.
5. Clasifica por rol y aplica el orden de dibujo en una operacion.NET.
6. Continuan los atributos y cantidades del motor sin modificar formulas.

No se emite un INSERT por simbolo ni uno por franja. No se toco el toperol,
que conserva su patron existente. Las capsulas mantienen sus bulges/arcos.

## Mediciones de la corrida final completa

| Caso | Generar | Empaquetar, lote y ordenar | REGEN | Guardar | Total sin guardar |
|---|---:|---:|---:|---:|---:|
| 5.5.2,188m | 6,750s | 4,765s | 0,125s | 0,735s | **11,640s** |
| Lote.NET,188m | 6,672s | 5,031s | 0,093s | 0,282s | **11,796s** |
| 5.5.2,800m | 24,219s | 27,859s | 0,313s | 0,640s | **52,391s** |
| Lote.NET,800m | 23,000s | 22,625s | 0,313s | 0,609s | **45,938s** |

Total incluyendo guardar:188m12,375s ->12,078s;800m53,031s ->46,547s.
No vender la disminucion del guardado de188m como mejora de generacion:
sin guardar, la corrida final de188m fue ligeramente mas lenta.

La primera corrida188m arrojo9,718s ->8,001s sin guardar, pero la repeticion
NO sostuvo ese ahorro. Se conserva la variacion y no se elige solo el mejor
numero. El arranque de Civil, carga del motor y asserts estan fuera de esos
tiempos; si se incluyeron generacion, recortes, empaquetado y regeneracion.
El prototipo todavia deja el calculo de coordenadas/recortes enLISP: no prueba
el rendimiento de un motor entero reescrito en.NET.

## Validaciones:55 OK,0 fallos numericos

`result-final.txt` separa la ultima corrida completa del log inicial.

- 188m:4702 geometrias de guia/juntas exactamente iguales en DXF a1e-9.
- 800m:20001 geometrias exactamente iguales a1e-9. No reduccion de detalle.
- Bloque final valido,0INSERTanidados,0entidades generadas sueltas por barrido
  completoXDATA; los cuatro casos base/candidato terminan empaquetados.
- 16cantidades/parametros identicos por comparacion A/B en cada longitud,
  incluyendo areas,ML,UND y sobreancho1m por lado. No hay terreno real en
  este fixture: la igualdad de cantidades no certifica calculos contraSUP_TN.
- Todos losHATCH de materiales del caso188m conservan sus datosDXF
  (sin identificadores/propietarios); no se cambiaron patron, escala ni angulo.
- Tabla real de orden consultada: ordenporroles correcto en188y800m.
- Ruta de respaldo de guia sobre region con hueco transversal: mismas
  coordenadas/bulges/cantidad que la base, orden correcto.
- Lote intencionalmente mal formado: rechaza la operacion y la transaccion
  NO deja entidades parciales (se verifica Count antes/despues).

### Comprobacion visual: limite explicito

Se intento exportar desde Civil aWMF un detalle de las dos versiones, sin
controlar el escritorio. Civil rechazo ambas salidas: `AutoCAD main window
is invisible`. No se forzo mostrar ni controlar una ventana. Por tanto **no
hay nueva imagen renderizada verificada**; si hay igualdad de geometriaDXF,
datos dehatches y orden de dibujo. No llamar a esto inspeccion visual completa.

## Otra mejora medida: ordenar en.NET

En el bloque PLANO del prototipo188m, reenumerar y ordenar mediante el
metodoLISP/COM existente tardo5312ms; hacerlo por.NET tardo110ms.
Son mediciones sobre ese bloque, NO un ahorro de5s que pueda restarse otra
vez al total: el prototipo ya usa el orden.NET dentro de su empaquetado.
No extrapolar ese factor a la version552, que ordena menos objetos de primer
nivel porque anida la franja. La ventaja puede ser util en otros bloques planos.

## Mas opciones encontradas, priorizadas por evidencia

| Opcion | Evidencia en el codigo / prueba | Trabajo pendiente |
|---|---|---|
| Lote.NET y orden por roles | Ensayado arriba, precision numerica conservada | Integrar ciclo completo y verificar render/versiones |
| Cache de obstaculos por creacion de anden | anden-cutout-blocks hace3ssgetglobales; apply-anden-cutouts se llama desde acabado, accesibilidad y mediciones | Medir en copia representativa con muchos objetos, no en vacio |
| Cache de cajas/huellas y filtro espacial conservador | objects-bbox-overlap-p consulta2cajasCOM por candidato; block-footprint-region explota/reconstruye huellas | Cache solo durante el comando, invalidar tras cambios; conservar booleano exacto |
| Hatches de materiales en lotes.NET | add-solid-hatch/add-user-hatch y variantes ejecutan varias llamadasCOM y evaluacion por pieza | Prototipo A/B con mismos limites, origen, angulo, fase y control anticirculos |
| Muestreo de curva en lote y reutilizacion | curve-pt/curve-tangent y puntosconarcos se consultan repetidamente | Conservar tolerancias y punto/tangente exactos; medir por fase |

La cache de obstaculos tiene especial interes para explicar la diferencia
entre dibujo limpio y maestro pesado. El codigo confirma repeticion, **no
se midio aun su ahorro** ni se atribuyen los cinco minutos del usuario a esa
causa sin reproducir su dibujo. No almacenar una cache global indefinida:
debe invalidarse con cambios delDWG o limitarse a una creacion controlada.

No se propone quitar simbolos, bajar resolucion, desactivarUNDO, saltar
booleanos/cantidades o eliminar la proteccion contra rellenos curvos grandes.
Tampoco se presenta una previsualizacion simplificada como anden terminado.

## Incidencias del laboratorio y economia de verificacion

La primera corrida800m se interrumpio al enviar porCOM un seguimiento antes
de que terminara. La comprobacion adicional encontro que aun no existia la
cuarta definicion de bloque. `round1.txt` conserva el error. No es evidencia
de fallo del constructor; tampoco se conto como un caso aprobado.
Se rehizo en un solo lote encadenado, sinSendCommand duranteBUILD.
El verificador tambien tenia una conversion sort-i->nth por elementoO(n2);
se cambio a ordenar pares indexados conservando duplicados. No se redujo el
numero de geometrías ni la tolerancia para ganar tiempo.
PIDpropios23124y8164cerrados; no quedaron laboratorios trabajando en segundo plano.

## Reproducir y continuar

Laboratorio: C:/Users/juanbusper/Documents/URBANISMO/work/anden_batchnet/.
baseline.lsp = be4b704:urbanismo_cantidades.lsp. candidate.lsp = esa misma
fuente reemplazando, SOLO dentro de package-anden, la llamada a
urb:set-block-draw-order por `(bn:finish block-name handle)`.
CompilarBatchGuide.cs yCheckBatch.cs con cscFramework64v4 y referencias2023
acmgd/acdbmgd/accoremgd. AmbasDLL tienen guardia delfixture exacto; no distribuir
como entrega general. run.scr carga native.lsp que ejecuta188/800 y accept.lsp.
No ejecutar en el maestro: el helper verifica la ruta absoluta antes de crear.

Hashes de lo probado:
- BatchGuide.dll:6FB6DB43F2C665DF7C496B58F9DDEC42CEC0356E9501035A132A461AE224617E
- candidate.lsp:98701DAC3B8A92166ABC08FB9F347D48937D794331CA6161B5392A6AB46A9D01
- batch.lsp:934463BC45C213F4C18B12E536EB18B010497F5C670C1FEA273674E1425015B4

Antes de convertirlo en entrega: cubrir sinGUIA (el helperactual solo ordena
cuando procesa un lote), cancelacion y limpieza decola, edicion/recorte de
bloques existentes, todas las llamadas compartidas desde rampas, otros formatos,
y DLL.NET8 para2025/2026. El prototipo actual no esta listo para sustituir
la instalacion del usuario; se guarda para integrar sin repetir investigacion.

Fuente/bundle productivos siguen552 y SHA256
10D27FCF85A2675C29727471DC77F13364913783C0CE8EB97755E668A6AE3A80.

## Referencias oficiales consultadas

- [Crear entidades con AppendEntity](https://help.autodesk.com/cloudhelp/2026/ENU/OARX-DevGuide-Managed/files/GUID-F5601807-2FA9-486F-A212-E693D452D81F.htm)
- [Definir bloques y emitir dentro](https://help.autodesk.com/cloudhelp/2026/ENU/OARX-DevGuide-Managed/files/GUID-DF67671C-101D-4917-808B-DD2C5BE3C7E9.htm)
- [Funcion AutoLISP implementada en.NET](https://help.autodesk.com/cloudhelp/2016/ENU/AutoCAD-NET/files/GUID-3B2760FE-A0DC-4229-AEBE-5CC83290BA95.htm)
- [Consultar orden real](https://help.autodesk.com/cloudhelp/2018/ENU/OARX-ManagedRefGuide/files/OREFNET-Autodesk_AutoCAD_DatabaseServices_DrawOrderTable_GetFullDrawOrder_byte.html)
- [Transacciones y actualizacion grafica](https://help.autodesk.com/cloudhelp/2022/ENU/OARX-DevGuide/files/GUID-653BD3D5-1859-413A-AE17-ACB64D6E4C02.htm)
- [Evaluacion de hatches: interseccion/triangulacion](https://help.autodesk.com/cloudhelp/2022/ENU/OARX-ManagedRefGuide/files/OARX-ManagedRefGuide-Autodesk_AutoCAD_DatabaseServices_Hatch_EvaluateHatch__MarshalAsUnmanagedType_U1__bool.html)
