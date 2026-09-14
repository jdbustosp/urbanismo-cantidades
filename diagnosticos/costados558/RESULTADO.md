# Costados en curvas y anchos variables — 5.5.8

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-14 13:58 America/Bogota.
Base 592b452. Civil 3D 2023 real, laboratorio local costados558. Originales intactos.

Cambios: el lado interno/externo del prefabricado se decide mediante tangente
local y sentido del contorno. El centroide/espejo anterior colocaba un costado
externo hacia dentro en la curva ensayada. El sendero ahora resta las huellas
reales de sus prefabricados antes de crear el hatch; descuento guardado a seis
decimales en la misma posicion de XDATA. Sin costados conserva su flujo anterior.
El contorno arquitectonico no cambia. El hatch recortado es no asociativo;
editar posteriormente el contorno por grips no recalcula ese recorte.

Antes: sendero interno con 24.334 m2 de hatch debajo de las piezas; externo con
12.2414 m2 indebidamente dentro. Despues: superposicion hatch/prefabricados ~0
(tolerancia 1e-5 m2); externos completamente fuera; area neta interna 358.206 m2
frente a 382.54 m2 brutos. Constructor+chequeo: 0.3-0.8 s en los casos ensayados.
Anden curvo de ancho variable, unos 60 m, con guia/toperol y prefabricados:
build+pack 2.344 s, bloque generado, area neta 358.206157 m2. No extrapolar a 188m.

48 comprobaciones finales OK: curvas en ambos sentidos, interno/externo, un lado,
U y ensanchamiento 2 a 18m; acabado recortado, contorno intacto y colector de
cantidades con area neta. Scripts/resultados adjuntos. Las primeras dos fallas
del ensayo fueron la expectativa de prefabricado ENTERAMENTE dentro del cierre:
se identifico una cuna de remate de 0.00404026 m2, situada al extremo (caja x1060
a1060.04, y2000 a2000.2). Cara perpendicular a tangente frente a cierre oblicuo.
El ensayo final exige cualquier resto fuera del contorno confinado al remate,
dentro de 1.5 anchos de UN extremo; no se relajo el control del hatch ni cantidades.

## Pendiente especifico

En U de envolvente cuadrada, la inferencia automatica de los DOS costados es
ambigua: las pruebas trasladadas dieron ejes 0/pi/2 y longitudes de cadenas
78+30 frente a30+102 m. Las piezas siguen esas cadenas, pero falta estabilizar
la eleccion y/o permitir que el usuario indique las tapas/eje en esas formas.
No declarar orientacion arquitectonica universal solucionada. El usuario pidio
cerrar para conservar tokens; se entrega lo ya probado y se conserva este hallazgo.
Sin revision visual nativa ni Civil2025/26; sin exportar Excel ni calcular terreno.
