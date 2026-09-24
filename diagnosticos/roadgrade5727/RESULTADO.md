# v5.7.27 — rasantes de vías como referencia de tierras

Fecha: 2026-09-23, 21:52 America/Bogota. Agente: Codex.
Equipo: BOG085CD119BDQN. Base: 4c7efe9.

## Caso del usuario y causa

En una copia local del maestro guardado el 2026-09-23 21:29 se encontraron
27 objetos de vía con URB_VIA. Veintiséis tenían rasante recuperable; uno,
`VIA-25` (handle `1E4E4C`, LWPOLYLINE), no: registro de 23 campos sin cotas
de diseño ni movimiento, estado PENDIENTE, creado en modo Pendiente. No es
posible inferir de ese objeto la cota inicial y la pendiente que faltan.

La búsqueda automática llamaba al lector interactivo por cada vía candidata.
Una vía antigua o incompleta podía abrir un selector de cotas dentro del
cálculo de un andén, sendero o zona verde. Además, al reconstruir vías antiguas,
leía como capa de cotas el campo 7 (modo) cuando la capa real está en el 8.
El empaquetado de vías solo transfería LDATA de la huella; la rasante completa
quedaba reducida a las muestras compactas del XDATA del bloque.

## Corrección

- La selección automática inspecciona las vías sin pedir clics y omite las
  que no tienen rasante. Los errores de un candidato se aíslan para seguir
  buscando; al usar una referencia se informa el problema concreto.
- La reconstrucción consulta la capa guardada en URB_VIA[8].
- Al seleccionar texto anidado dentro de una vía, prevalece la vía. Si carece
  de rasante, se identifica por nombre y se ofrece escoger otra referencia.
- El bloque de vía conserva la rasante completa y las fuentes de cotas; EDITAR
  las devuelve al contorno temporal. Si no se pueden transferir, el empaquetado
  falla sin borrar el contorno fuente.

## Verificación y límites

- Civil 3D 2023 sobre copia local fresca del maestro: 9 PASS / 0 FAIL,
  40.22 s en la versión final. Incluye VIA-25 sin rasante, omisión automática, empaquetado real,
  lectura de un perfil con tres estaciones desde el bloque y recuperación al
  desempacar para EDITAR.
- Core Console 2023: selección de URB_VIA[8] PASS, 16.16 s. El test usa un
  colector de textos controlado y fallaría con el índice 7 previo.
- Core Console 2023: la ruta automática compartida por senderos y zonas verdes
  detectó `VIA-24` en una huella de laboratorio sobre su eje y devolvió cota
  de diseño 2558.0360; PASS, 12.11 s. No calculó volumen contra SUP_TN.
- El maestro y la copia fresca tuvieron SHA256 idéntico después de las
  pruebas; el original no se abrió para editar ni se guardó. No se tocaron
  libros de presupuesto.
- La fuente 5.7.27 y la copia instalada en este equipo coincidieron con SHA256
  `F5759D4153CC4202CF36EEBA8BFA90308E6C2C2563F90B9CD291496C55B67566`.
- La captura no contiene el handle del andén que lanzó `Unknown exception`;
  esa excepción literal no se reprodujo. La selección de rasante quedó
  protegida, pero los volúmenes completos de ese andén y de senderos/zonas
  verdes no fueron recalculados en esta prueba. La interacción DCL y Civil 3D
  2026 requieren confirmación en la sesión del usuario.

Para utilizar VIA-25 como cota inicial o referencia de movimiento: EDITAR esa
vía, asignar al menos una cota y pendiente (o dos cotas), recalcular y guardar.
Los movimientos ya pendientes en elementos existentes se recalculan desde
EDITAR; no se reescriben automáticamente al cargar el motor.
