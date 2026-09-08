# v4.73.1 — optimizacion y prueba con Maipore

## Cambios en el mismo motor

- q-aggregate agrupa mediante ordenacion por clave e indice. Conserva exactamente orden de primera aparicion, orden de suma, estados, conteos y registros repetidos. Evita busquedas lineales y sustituciones de listas crecientes.
- q-handle lee el grupo DXF 5, evitando conversion y lectura COM por entidad; conserva entrada ename/VLA mediante as-ename.
- ppto-write-agg rellena las filas restantes de TablaAgg con un repeat de longitud conocida, sin recalcular length en cada iteracion.
- rows-timed detiene la exportacion si un colector falla. Antes convertia la excepcion en nil y podia continuar con memorias parciales. Una disciplina realmente vacia sigue siendo valida.

## Pruebas ejecutadas

- Suite de regresion: 50 OK / 0 FALLOS.
- Benchmark en Core Console: igualdad exacta contra implementacion anterior para 0, 1, 100, 1000 y 5000 filas. Ultima corrida, 5000 filas: 2828 ms anterior / 94 ms nueva. Es una medicion sintetica de agrupacion, NO del tiempo total de exportacion.
- Fallo inyectado de colector: aborta; colector vacio: admitido.
- Handle real de INSERT e input nil: correctos.
- Balance estructural y diff --check correctos; manifiesto e instalador coherentes con 4.73.1.
- Motor instalado y repositorio: SHA256 5023E0B216759D2A53939B90250C0F904856A36AEC0C5793390FB4A9572E6F65. El instalador advirtio DLL bloqueada, pero la DLL 2025+ instalada y la del repo tienen hash identico; esta entrega no cambia DLL.

## Validacion nativa con copias del proyecto

Fuentes identificadas en 260915_ACTUALIZACION GENERAL PPTO: urbanismo maipore.xlsx y Memorias/URB_MASTER_GENERAL.dwg. Las rutas escritas originalmente por el usuario estaban separadas de otra forma. Copias locales en Documents/URBANISMO/work/maipore4740, fuera de las carpetas sincronizadas. Ninguna escritura de pruebas en los originales.

Civil 3D 2026 completo se ejecuto oculto con /b y ActiveX real. Excel se creo en instancia propia. Se invoco urb:ppto-run con su opcion headless existente; no hubo adaptadores COM ni DCL en este ensayo.

1. Primera exportacion: termina y guarda; valores y formulas de las 11 hojas iguales a los originales al reabrir la copia.
2. Segunda exportacion: se cambia MEMORIAS!J2 SOLO en la copia de 906.352 a 123456.789. El exportador repone 906.352, genera 7658 filas, alcanza guardado y termina. La copia guardada vuelve a coincidir celda por celda en valores/formulas de las 11 hojas con la fuente. El ensayo cargo el candidato 4.73.1 antes del ajuste final de fallo de colector; este ajuste se comprobo separadamente con fallo inyectado y regresion.
3. Conciliacion independiente mediante lectura Python (sin guardar desde Python): 7658 filas, 1658 claves especificacion/subetapa/red; cero discrepancias con TablaAgg a tolerancia relativa 1e-6 con piso absoluto 1e-6.

Los datos de trabajo y los JSON con detalle permanecen en el laboratorio local; no se incluyen los libros ni dibujos en Git.

## Hallazgos pendientes

- Una fila existente figura [SIN MATCH x3] Cabezal de descarga en concreto, red ALC-PLUVIAL. Requiere resolver la equivalencia con la partida correcta; no se invento una asignacion.
- Nombre definido MEMORIA_CALCULO_RANGO apunta a #REF!; TM_MEMORIAS y la firma de 12 columnas son validos. Revisar consumidores externos antes de eliminar el nombre legado.
- POR EJECUTAR contiene cantidades como valores y usa el puente del exportador; no depende actualmente de formulas TablaMemorias/TablaAgg. No sustituir esta estructura por formulas de un libro antiguo.
- Falta verificar cambios de etapa/subetapa y rollback/UNDO con fallos de escritura reales. La revision previa de esa ruta sigue vigente.
- La consulta individual aun recorre todo el dibujo; optimizar sin perder controles de duplicados globales requiere un indice con invalidacion correcta.
- No se certifica precision topografica, recálculo independiente de superficies ni cambios en XREF: se exporto el DWG guardado. No se copio el arbol completo de referencias externas.
- La igualdad celda por celda cubre valores y formulas; no certifica todos los objetos Excel, pivotes, segmentaciones ni el tiempo de recalculo completo. La prueba nativa de apertura independiente devolvio estado xlPending despues de CalculateFull y no se presenta como recalculo final concluido.

## Repetir

La suite base tiene runner en ../hardening4730/ejecutar.ps1. benchmark.lsp contiene la implementacion previa como oraculo y pruebas del motor; ajustar la ruta local de motor.lsp y ejecutar mediante un .scr en Core Console sobre una fixture. El archivo e2e_verify.lsp es un harness de laboratorio con rutas locales explicitas: preparar las copias primero, nunca redirigirlo al libro vigente. No ejecutar dentro de una sesion de trabajo.
