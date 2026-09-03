;;; perf.lsp (2026-09-03) - diagnostico de LENTITUD (reporte del usuario:
;;; borrar un elemento o "actualizar" tarda mucho) sobre COPIA del master
;;; viejo de Drive (el que el usuario tiene abierto). Mide:
;;;  - censo (inserts, defs, capas, regapps)
;;;  - costo del reactor de borrado VIEJO (barrido total) vs NUEVO (filtrado)
;;;  - borrado real de un elemento (con reactor nuevo activo)
;;;  - REGEN
;;;  - PPTOEXPORTAR (el "ACTUALIZAR") con el resolutor multi-PC 4.68.1
(defun pf:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/perf0903/perf.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun pf:ms () (getvar "MILLISECS"))

(defun c:PERF1 (/ t0 ss n-ins n-pto n-tra bd n-defs n-lay n-app en res lay)
  ;; censo
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq n-ins (if ss (sslength ss) 0))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_*,CANT_PUNTO_*"))))
  (setq n-pto (if ss (sslength ss) 0))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_*,TRAMO_*,CANT_TRAMO_*"))))
  (setq n-tra (if ss (sslength ss) 0))
  (setq bd (tblnext "BLOCK" T) n-defs 0)
  (while bd (setq n-defs (1+ n-defs)) (setq bd (tblnext "BLOCK")))
  (setq bd (tblnext "LAYER" T) n-lay 0)
  (while bd (setq n-lay (1+ n-lay)) (setq bd (tblnext "LAYER")))
  (setq bd (tblnext "APPID" T) n-app 0)
  (while bd (setq n-app (1+ n-app)) (setq bd (tblnext "APPID")))
  (pf:log (strcat "CENSO: inserts=" (itoa n-ins)
    " puntosMP=" (itoa n-pto) " tramos=" (itoa n-tra)
    " defsBloque=" (itoa n-defs) " capas=" (itoa n-lay)
    " regapps=" (itoa n-app)))
  ;; costo del barrido VIEJO del reactor (todos los inserts, COM por c/u)
  (setq t0 (pf:ms))
  (setq ss (ssget "_X" '((0 . "INSERT"))) res 0)
  (if ss
    (progn
      (setq en 0)
      (while (< en (sslength ss))
        (mp:att-alist (ssname ss en))
        (setq res (1+ res) en (1+ en)))))
  (pf:log (strcat "BARRIDO VIEJO (att-alist de TODOS los inserts): "
    (itoa res) " en " (rtos (/ (- (pf:ms) t0) 1000.0) 2 1) " s"))
  ;; costo del reactor NUEVO completo (filtrado 4.68.2)
  (setq t0 (pf:ms))
  (mp:cleanup-orphan-auto-points)
  (pf:log (strcat "REACTOR NUEVO (cleanup filtrado completo): "
    (rtos (/ (- (pf:ms) t0) 1000.0) 2 1) " s"))
  ;; borrado real de un tramo (dispara el reactor via comando ERASE)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_SAN_*"))))
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq en (ssname ss 0))
      (setq t0 (pf:ms))
      (vl-cmdf "_.ERASE" en "")
      (pf:log (strcat "ERASE de 1 tramo (reactor incluido): "
        (rtos (/ (- (pf:ms) t0) 1000.0) 2 1) " s"))
      (vl-cmdf "_.UNDO" "1")))
  ;; regen
  (setq t0 (pf:ms))
  (vl-cmdf "_.REGEN")
  (pf:log (strcat "REGEN: " (rtos (/ (- (pf:ms) t0) 1000.0) 2 1) " s"))
  (pf:log "FIN-PERF1")
  (princ))
(princ "\nperf listo")(princ)
