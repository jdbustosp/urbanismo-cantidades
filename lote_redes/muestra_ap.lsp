;; MUESTRA AP (2026-08-26): UN tramo real de alumbrado para visto bueno,
;; sobre copia de SERIE 6 (con los bloques CR T1..T5 visibles de fondo):
;; 2 cajas AP-274 reales + tramo caja a caja sobre la red + 2 postes
;; reales, cada uno con sus 2 luminarias ref 192-93.
(vl-load-com)
(defun ma:caja (pt rot id / obj a hh)
  (mp:insert-cant-point "CAMARA_CS274" pt
    (list (cons "ID" id) (cons "TIPO_CAJA" "CS-274")
          (cons "CIRCUITO_AP" "CR T1")))
  (setq obj (vlax-ename->vla-object (entlast)))
  (setq hh 0.54)
  (vla-put-Rotation obj rot)
  (foreach a (vlax-invoke obj 'GetAttributes)
    (cond
      ((= (strcase (vla-get-TagString a)) "ETIQUETA")
        (vla-put-Rotation a 0.0)
        (vl-catch-all-apply 'vla-put-TextAlignmentPoint
          (list a (mp:3d (list (car pt) (+ (cadr pt) hh 0.45) 0.0)))))
      ((= (strcase (vla-get-TagString a)) "NUM_VIS")
        (vla-put-Rotation a 0.0)
        (vl-catch-all-apply 'vla-put-TextAlignmentPoint
          (list a (mp:3d (list (car pt) (- (cadr pt) hh 0.5) 0.0))))))))

(defun c:MUESTRAAP (/ ss i)
  (mp:ensure-layers)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_*"))))
  (setq i 0)
  (repeat (if ss (sslength ss) 0) (entdel (ssname ss i)) (setq i (1+ i)))
  ;; cajas reales del CR T1
  (ma:caja '(83142.3168 95971.8578 0.0) 1.2217 "A274-1")
  (ma:caja '(83091.0162 95985.1677 0.0) 1.2217 "A274-2")
  ;; tramo caja a caja (segmento real de 0_0 RED BT SUBT PROY)
  (mp:insert-cant-tramo "TRAMO_E_BT_AP"
    '(83142.3168 95971.8578 0.0) '(83091.0162 95985.1677 0.0)
    (list (cons "RED" "ELECTRICA-BT-AP") (cons "TIPO_RED" "AP")
          (cons "UBICACION" "ANDEN O ZONA VERDE")
          (cons "DUCTOS" "2") (cons "DIAM_DUCTO" "3")
          (cons "MATERIAL_DUCTO" "PVC") (cons "CONDUCTOR" "3x4+4 THW")
          (cons "CIRCUITO_AP" "CR T1")
          (cons "POZO_INI" "A274-1") (cons "POZO_FIN" "A274-2")))
  ;; postes reales con sus luminarias
  (mp:insert-cant-point "POSTE_ELEC" '(83139.6447 95971.5156 0.0)
    (list (cons "ID" "P-1") (cons "TIPO_RED" "AP") (cons "ALTURA_M" "10")
          (cons "CIRCUITO_AP" "CR T1")
          (cons "LUMINARIAS" "2") (cons "TIPO_LUMINARIA" "192-93")))
  (mp:insert-cant-point "POSTE_ELEC" '(83088.3440 95984.8256 0.0)
    (list (cons "ID" "P-2") (cons "TIPO_RED" "AP") (cons "ALTURA_M" "10")
          (cons "CIRCUITO_AP" "CR T1")
          (cons "LUMINARIAS" "2") (cons "TIPO_LUMINARIA" "192-93")))
  (command "_.ZOOM" "_W" "83080,95958" "83152,95996")
  (princ "\nMUESTRA AP lista."))
(c:MUESTRAAP)
