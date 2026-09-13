# Regresion del disco de HATCH curvo — 5.0.3

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-13 11:23 America/Bogota.

Scripts exactos de la verificacion final; adaptar rutas antes de otro PC.
Nunca ejecutar sobre el maestro. final2.lsp hace QSAVE y agrega rellenos de
prueba: usar exclusivamente una copia extraida con REGION y HATCH del caso.
Laboratorio local: C:/Users/juanbusper/Documents/URBANISMO/work/disco503/.
Core Console 2023 ejecuta unit.lsp; Civil 3D 2023 real ejecuta final2.lsp.
SCR corto: (load "ruta/script.lsp"), luego _.QUIT y _Y, cada uno en su linea.

Resultados: unit.txt 41 regresiones/0 fallos y pruebas de arcos horarios,
antihorarios, cruce 2*pi y circulos genuinos. final2.txt 227 fuentes intactas,
0 pendientes, idempotencia y 212 rellenos nuevos; carga/reparacion 3485 ms.
Revisar PNG: antes.png reproduce disco, final2_verified.png no lo muestra.
La imagen final_verified.png del primer intento FALLA: omitio espacio Modelo.
El helper aislado repair.lsp reparo 238 HATCH y dio after.png sin disco.
La suma grafica de areas paso 782.662646 a 782.657948 m2 (<0.0006%);
son rellenos superpuestos, no el area presupuestable. Fuentes exactas intactas.
La comprobacion de carga no reemplaza la visual ni mide generar 188 ml.
