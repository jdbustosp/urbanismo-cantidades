;;; diag.lsp (2026-09-02) - diagnostico SIN mutacion:
;;; DIAGACC: para AC-461/AC-500, los 5 tramos ACU mas cercanos (distancia
;;;   perpendicular, proyeccion, longitud, extremos cerca del accesorio).
;;; DIAGVIA: atributos VIA_*SOBREANCHO* visibles de las 4 vias vs esperado.
(defun dg:log (msg)
  (if *dg-f* (write-line msg *dg-f*))
  (princ (strcat "\n" msg)) (princ))

(defun dg:tramo-ends (en / ed p rot atts l)
  (setq ed (entget en))
  (setq p (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
  (setq atts (mp:att-alist en))
  (setq l (distof (mp:getval "LONGITUD_2D" atts
            (mp:getval "LONGITUD" atts "0"))))
  (if (or (null l) (<= l 0.0)) (setq l 0.0))
  (list (car p) (cadr p)
        (+ (car p) (* l (cos rot))) (+ (cadr p) (* l (sin rot))) l))

(defun dg:pt-seg (px py x1 y1 x2 y2 / dx dy len2 t0 cx cy len)
  (setq dx (- x2 x1) dy (- y2 y1))
  (setq len2 (+ (* dx dx) (* dy dy)) len (sqrt len2))
  (if (< len2 1e-12)
    (list (distance (list px py) (list x1 y1)) 0.0 0.0)
    (progn
      (setq t0 (/ (+ (* (- px x1) dx) (* (- py y1) dy)) len2))
      (setq cx (+ x1 (* (max 0.0 (min 1.0 t0)) dx))
            cy (+ y1 (* (max 0.0 (min 1.0 t0)) dy)))
      (list (distance (list px py) (list cx cy)) (* t0 len) len))))

(defun c:DIAGACC (/ ss i en atts id eti accs item tramos res lst cod pc)
  (setq *dg-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/diag.txt" "a"))
  (setq accs nil)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq atts (mp:att-alist en))
      (setq id (strcase (mp:getval "ID" atts ""))
            eti (strcase (mp:getval "ETIQUETA" atts "")))
      (foreach cod (list "AC-500" "AC-461")
        (if (or (vl-string-search cod id) (vl-string-search cod eti))
          (setq accs (cons (list cod (cdr (assoc 10 (entget en))) eti) accs))))
      (setq i (1+ i))))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 tramos nil)
  (if ss (while (< i (sslength ss)) (setq tramos (cons (ssname ss i) tramos)) (setq i (1+ i))))
  (foreach item accs
    (setq pc (cadr item))
    (dg:log (strcat "=== " (car item) " eti[" (caddr item) "] en ("
      (rtos (car pc) 2 2) ", " (rtos (cadr pc) 2 2) ")"))
    (setq lst nil)
    (foreach en tramos
      (setq res (dg:tramo-ends en))
      (setq lst (cons (append
        (dg:pt-seg (car pc) (cadr pc)
          (nth 0 res) (nth 1 res) (nth 2 res) (nth 3 res))
        (list (distance (list (car pc) (cadr pc)) (list (nth 0 res) (nth 1 res)))
              (distance (list (car pc) (cadr pc)) (list (nth 2 res) (nth 3 res)))))
        lst)))
    (setq lst (vl-sort lst (quote (lambda (a b) (< (car a) (car b))))))
    (setq i 0)
    (foreach r lst
      (if (< i 5)
        (dg:log (strcat "  d=" (rtos (nth 0 r) 2 3)
          " tproj=" (rtos (nth 1 r) 2 2)
          " len=" (rtos (nth 2 r) 2 2)
          " dExtIni=" (rtos (nth 3 r) 2 3)
          " dExtFin=" (rtos (nth 4 r) 2 3))))
      (setq i (1+ i))))
  (dg:log "FIN-DIAGACC")
  (close *dg-f*) (setq *dg-f* nil)
  (princ))

(defun c:DIAGVIA (/ ss i be d atts nombre area span a1 a2)
  (setq *dg-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/diag.txt" "a"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons -3 (list (list "URB_VIA"))))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            d (urb:get-xdata-strings be "URB_VIA")
            atts (urb:block-attribute-values (vlax-ename->vla-object be))
            nombre (urb:safe-string (nth 1 d) "VIA")
            area (atof (urb:safe-string (nth 17 d) "0"))
            span (atof (urb:safe-string (nth 18 d) "0"))
            a1 (urb:safe-string (cdr (assoc "VIA_AREA_SOBREANCHO_M2" atts)) "?")
            a2 (urb:safe-string (cdr (assoc "VIA_SOBREANCHO_M2" atts)) "?"))
      (dg:log (strcat "VIA " nombre " | att AREA_SOBRE=" a1
        " att SOBRE=" a2 " | esperado AREA_SOBRE="
        (rtos (+ area (* span 2.0)) 2 1) " SOBRE=" (rtos (* span 2.0) 2 1)))
      (setq i (1+ i))))
  (dg:log "FIN-DIAGVIA")
  (close *dg-f*) (setq *dg-f* nil)
  (princ))
(princ "\ndiag listo")(princ)
