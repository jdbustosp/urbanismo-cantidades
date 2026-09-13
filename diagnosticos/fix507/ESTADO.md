# Estado verificado, entrega aun inconclusa

**REGISTRO HISTORICO SUPERADO:** consultar [RESULTADO.md](RESULTADO.md) para
el cierre de5.0.7. Se conserva este estado inicial como trazabilidad del fallo.

Agente: Codex. Equipo: BOG085CD119BDQN. 2026-09-13 17:35 America/Bogota.
Base Git: 919759e. Cambios locales 5.0.7 no instalados ni entregados como validados.

- Ocho regresiones focales pasan en Civil 3D 2023 real.
- Tramo9761C: guardar, reabrir y resincronizar conserva clave2559.00 en COPIA.
  Es cota sintetica para probar; no es aprobacion de la cota real de DOM41.
- Curva188 m: desaparece el error de punto82806.4. BUILD77.344s sin empaquetado.
- Empaquetado curvo sigue rechazado: area neta660.544254, acabados660.360653;
  faltan0.183601 m2 de geometria de acabado. No se ha reducido la tolerancia.
- Rectangulo10 m llega a bloque; PACKAGE41.297s. No prueba el bloque curvo.
- Falta cerrar geometria/areas, bloque sin piezas sueltas, tiempos, limites de
  hatches y continuidad tactil en la corrida integral; despues instalar, commit/push.
- DWG/Excel originales no modificados. Bundle instalado sigue5.0.6.

Siguiente paso concreto: localizar el residuo entre contorno neto y union de
acabados en B490B del fixture final.dwg. Reparar transiciones/recorte, no normalizar
cantidades para ocultar huecos. Reutilizar el dibujo generado; no repetir arranque
y generacion completa para diagnosticar exclusivamente el empaquetado.
