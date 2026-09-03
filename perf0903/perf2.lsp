;;; perf2 - validar la compuerta del reactor (4.68.2)
(defun p2:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/perf0903/perf2.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))
(defun c:PERF2 (/ t0 ss en)
  ;; borrar un elemento NO-tramo (un prefabricado o texto): debe ser rapido
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq en (ssname ss 0))
      (setq t0 (getvar "MILLISECS"))
      (vl-cmdf "_.ERASE" en "")
      (p2:log (strcat "ERASE NO-tramo (prefab): "
        (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 2) " s"))
      (vl-cmdf "_.UNDO" "1")))
  ;; borrar un tramo: paga el escaneo (esperado, pero solo aqui)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_SAN_*"))))
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq en (ssname ss 0))
      (setq t0 (getvar "MILLISECS"))
      (vl-cmdf "_.ERASE" en "")
      (p2:log (strcat "ERASE tramo (escaneo esperado): "
        (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 2) " s"))
      (vl-cmdf "_.UNDO" "1")))
  (p2:log "FIN-PERF2")
  (princ))
(princ "\nperf2 listo")(princ)
