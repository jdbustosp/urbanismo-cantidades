;; Cargar motor 5.0.7 antes. Ejecutar SOLO en dibujo descartable.
;; Sin adaptadores: requiere AutoLISP/ActiveX reales. No ejecuta al cargar.
(defun test507:assert (name ok)
  (if (not ok) (error (strcat "FAIL: " name)))
  (princ (strcat "\nOK: " name)))
(defun test507:run (/ en vals actual r1 r2 combined)
  (test507:assert "LAST conserva XY"
    (equal '(82806.4 95030.0)
      (last (urb:chain-simplify-by-direction
        '((82700.0 95000.0) (82750.0 95000.0) (82806.4 95030.0)) 0.035)) 1e-9))
  (test507:assert "Pendiente final en porcentaje"
    (equal 10.0 (urb:grade-slope-at-distance 20.0 '((0.0 100.0) (10.0 101.0))) 1e-9))
  (test507:assert "Tres cotas colineales"
    (equal 101.0 (urb:design-z-from-picks
      '((100.0 (0.0 0.0)) (101.0 (10.0 0.0)) (102.0 (20.0 0.0))) 10.0 0.0) 1e-9))
  (setq en (entmakex '((0 . "POINT") (10 0.0 0.0 0.0)))
        vals '(("POZO_INI" . "A") ("POZO_FIN" . "B")
               ("COTA_CLAVE_INI" . "2.00") ("COTA_CLAVE_FIN" . "2558.00")))
  (mp:save-edited-claves en vals '(("COTA_CLAVE_INI" . "2559.00")))
  (setq actual (mp:apply-edited-claves en vals))
  (test507:assert "Cota editada prevalece" (= "2559.00" (mp:getval "COTA_CLAVE_INI" actual "")))
  (mp:save-edited-claves en actual '(("COTA_CLAVE_INI" . "")))
  (test507:assert "Vacio restaura herencia"
    (= "2.00" (mp:getval "COTA_CLAVE_INI" (mp:apply-edited-claves en vals) "")))
  (mp:save-edited-claves en vals '(("COTA_CLAVE_INI" . "2559.00") ("COTA_CLAVE_FIN" . "2558.50")))
  (test507:assert "Clave final independiente"
    (= "2558.50" (mp:getval "COTA_CLAVE_FIN" (mp:apply-edited-claves en vals) "")))
  (test507:assert "Cambio de pozo no usa clave ajena"
    (= "2.00" (mp:getval "COTA_CLAVE_INI"
      (mp:apply-edited-claves en (mp:alist-set vals "POZO_INI" "OTRO")) "")))
  (entdel en)
  (test507:assert "Union vacia" (null (urb:regions-union-copy nil)))
  (princ "\nTODO OK fix507") (princ))
