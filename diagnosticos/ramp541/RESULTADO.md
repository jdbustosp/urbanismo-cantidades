# Rampas 5.4.1 — verificacion e instalacion

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha/hora local: 2026-09-13 22:21 America/Bogota.
Base: 94ec9b3 (5.4.0, cambios de Claude conservados).
Commit de entrega: consultar `git log -- diagnosticos/ramp541/RESULTADO.md`.

## Cambios

- Peatonal: sardinel A86 en el borde posterior, 0.20m de espesor dentro
  del contorno; pavimento termina contra su cara interior. Remates laterales
  identificados A105 (dos unidades), no A81. Todo dentro del bloque peatonal.
- Vehicular, modo Tres puntos: primer punto inicia; segundo define direccion
  (frente fijo 10m); tercero define lado y fondo. Modo Dibujar conserva el
  contorno trazado por el usuario y no lo ensancha silenciosamente.
- A86 en longitud mayor10m, A85 en menor5.8m; A80 en ambas curvas.
  Se reserva el espesor frontal real0.20m hacia punto3, incluido el arranque
  de las curvas. El borde posterior conserva la posicion del tercer punto.
- Toperol en ambos costados exteriores y franja transversal; se recorta
  fisicamente contra las curvas. La guia del pavimento propio termina contra
  las franjas laterales, sin cruzarlas.
- Cantidad tactil tomada de area recortada. Sobre anden existente, la rampa
  cuenta sus nuevas tabletas pero no vuelve a contar base granular/arena.
- A86 peatonal emite suministro, instalacion y transporte con el catalogo
  actual. A105 conserva la actividad existente de remate FUNDIDO en sitio
  del capitulo peatonal (0.39m2 por remate), no se cambia a una compra de
  prefabricado sin autorizacion. Legacy A81 sigue exportando esa actividad.

## Referencia A85/A86

Documento oficial IDU: A85 = sardinel bajo; A86 = sardinel alto; A105 = remate.
Se mantienen los codigos solicitados por el usuario, se aclaran los nombres.
Fuente: https://www.idu.gov.co/Archivos_Portal/2022/Documentos/DISE%C3%91O%20IDU%201630-2020/D.3.Urbanisticos/Urbanismo/Detalles%20Urbanismo/PDF/DEUREP16-34-DEUREP20.pdf
No se cambiaron largos/pesos unitarios del catalogo del proyecto: no es una
auditoria de proveedor ni una verificacion de conformidad normativa.

## Evidencia

Civil 3D 2023 REAL, ActiveX, fixture LOCAL; no adaptador ni Core Console.
Laboratorio: C:/Users/juanbusper/Documents/URBANISMO/work/ramp541/.
Arranque unico PID20984 a22:12:11; primer lote ya produjo resultados a22:12:56.
Se reutilizo la misma sesion para pruebas focales posteriores, sin controlar
la pantalla. PID propio cerrado despues de QSAVE de la copia, antes de instalar.

- Baseline corresponde exactamente a94ec9b3:11 asserts fallan; invade la
  via0.20m, no tiene laterales completos ni sardinel posterior peatonal.
- Ultimo lote FINAL_541: **33 OK / 0 FAIL / 0 ERROR**, termina OVERLAY_DONE.
- Tres orientaciones:0rad/+lado,0.74rad/-lado y pi/+lado. Invasion minima
  -7.82e-14m (ruido numerico), tolerancia1e-6m. Solape tactil/prefab0m2.
- Vehicular10x4m: A86=10.00ML,A85=5.80ML,dos A80 curvos de2.88ML cada uno
  segun atributo redondeado; cuatro bloques prefab conservan destino vehicular.
- Tactil efectiva2.5875199m2 =12.9375995ML x0.20m;65 tabletas redondeadas.
  En la primera candidata habia0.0804801m2 de solape: test adicional lo
  detecto y se corrigio antes de entregar. No confundir candidata con final.
- Generacion completa del modulo vehicular vacio10x4m:328,406,344ms.
  NO es un benchmark del anden188m ni del DWG maestro cargado.
- Peatonal ancho util3m/fondo4m: A86 posterior3.60ML/0.72m2,A105=2.
- Sobre un anden generado y empaquetado realmente: deteccion OK, rampas
  sin base duplicada,65 tabletas nuevas contadas. Exportaciones internas
  de cantidades capturadas; no se escribio ni audito el Excel vigente.

## Instalacion y limites

Motor y manifiesto5.4.1. Instalador completo sin DLL bloqueada en este equipo.
SHA256 motor: C5B1635B3E1760C5911966082B392B0B31D22A1EBE412BCD2E202DD49F680423.
Reiniciar Civil 3D y recrear las rampas anteriores; no hay migracion automatica
de geometria vieja. No se modificaron originales DWG/Excel. Otros PCs no
inspeccionados: sincronizar repo; acaddoc>=5.3 carga repo al reiniciar.

Pendiente manual:1) Tres puntos con eje corto y tercer punto hacia anden;
2) repetir al lado opuesto;3) peatonal con A86 posterior. Si alguna pieza
queda del lado de la via, capturar version cargada y los tres puntos.
Pruebas numericas no equivalen a comprobar DCL/ribbon con clics ni todas las
versiones Civil. Tampoco prueban el enlace E2E de las nuevas filas al Excel.

## Metodologia agil aplicada

1. Estado/version/hash y lectura dirigida del codigo, no revisar todo el repo.
2. Probar el defecto contra baseline antes de validar el parche.
3. Un laboratorio pequeno, real, persistente; agrupar variantes y medir
   coordenadas, solapes, atributos y cantidades. Reusar sesion, no arranques.
4. Repetir solo pruebas afectadas; instalar comprobando hash; registrar
   resultados, limites y trazabilidad para Claude/segundo PC.

Mejoras siguientes: automatizar este lote en una orden con resumen OK/FAIL,
guardar cache por hash de motor+fixture+harness y consolidar helpers de
solapes. Evita releer logs completos y reconstruir contexto entre agentes.
No se afirma ahorro porcentual de tokens: no se midio consumo comparativo.

## Repeticion

`native.lsp` usa baseline.lsp y candidate.lsp en el laboratorio local y
escribe result.txt. Baseline=94ec9b3; candidate=motor de la entrega.
`overlay.lsp` se carga despues, en la misma sesion de laboratorio.
Antes de repetir, usar copia local nueva del fixture vacio; nunca ejecutar
rv:clear en un dibujo del usuario. `rv:final-only=T` omite baseline.
native_result.txt conserva corridas y presupuestos internos completos; el
ultimo START hasta OVERLAY_DONE es el lote final de33asserts.
