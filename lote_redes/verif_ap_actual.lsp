;; Verificar si los tramos AP existentes en el master siguen con
;; geometria correcta (0..distv) tras el bug de mp:normalize-tramo-
;; graphics, que tambien afectaba a TRAMO_E_BT_AP (no solo MT).
(setq pf (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/verif_ap_actual.txt" "w"))
(defun vf (m) (write-line m pf))
(setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_BTAP_*"))))
(setq n (if ss (sslength ss) 0) i 0 malos 0 buenos 0)
(while (< i n)
  (setq e (ssname ss i) ed (entget e))
  (setq bn (cdr (assoc 2 ed)))
  (setq distv (atof (vl-string-translate "_" "."
    (substr bn (+ 6 (vl-string-search "BTAP_" bn))))))
  (setq blkrec (tblsearch "BLOCK" bn))
  (setq be (cdr (assoc -2 blkrec)) x0 nil x1 nil ncirc 0)
  (while be
    (setq bd (entget be))
    (cond
      ((= (cdr (assoc 0 bd)) "LWPOLYLINE")
        (setq pts nil)
        (foreach p bd (if (= (car p) 10) (setq pts (cons (cadr p) pts))))
        (setq x0 (apply 'min pts) x1 (apply 'max pts)))
      ((= (cdr (assoc 0 bd)) "CIRCLE") (setq ncirc (1+ ncirc))))
    (setq be (entnext be)))
  (if (or (null x0) (> (abs x0) 0.02) (> (abs (- x1 distv)) 0.02) (> ncirc 0))
    (setq malos (1+ malos))
    (setq buenos (1+ buenos)))
  (setq i (1+ i)))
(vf (strcat "Tramos AP: " (itoa buenos) " OK (0..distv, sin circulos) | "
  (itoa malos) " con geometria mala | de " (itoa n)))
(vf "VERIFAP-OK")
(close pf)
(princ)
