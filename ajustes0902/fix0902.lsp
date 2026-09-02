;;; fix0902.lsp (2026-09-02) - dos intervenciones al master:
;;; AUDITSOBRE/FIXSOBRE: vias viejas sin sobreancho en la xdata URB_VIA
;;;   (nth 14/15) -> 1.00/1.00 (estudio AUS-10786-10) + refresco de los
;;;   atributos VIA_AREA_SOBREANCHO_M2 / VIA_SOBREANCHO_M2.
;;; SPLITACC: PILOTO pedido por el usuario - tramos ACU que PASAN POR
;;;   ENCIMA de un accesorio (AC-461 / AC-500) se parten en dos tramos
;;;   tramo-accesorio-tramo. Espera visto bueno antes del masivo.
;;; Requiere plugin cargado.

(defun fx:log (msg)
  (if *fx-f* (write-line msg *fx-f*))
  (princ (strcat "\n" msg)) (princ))

(defun fx:subst-nth (lst n val / i out)
  (setq i 0 out nil)
  (foreach x lst
    (setq out (cons (if (= i n) val x) out))
    (setq i (1+ i)))
  (reverse out))

(defun c:AUDITSOBRE (/ ss i be d nombre l r span area n-sin)
  (setq *fx-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/resultado.txt" "a"))
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_VIA")))) i 0 n-sin 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            d (urb:get-xdata-strings be "URB_VIA")
            nombre (urb:safe-string (nth 1 d) "VIA")
            l (atof (urb:safe-string (nth 14 d) "0"))
            r (atof (urb:safe-string (nth 15 d) "0"))
            area (atof (urb:safe-string (nth 17 d) "0"))
            span (atof (urb:safe-string (nth 18 d) "0")))
      (fx:log (strcat "VIA " nombre " | sobre_izq=" (rtos l 2 2)
        " sobre_der=" (rtos r 2 2) " | span=" (rtos span 2 1)
        " area=" (rtos area 2 1)))
      (if (and (<= l 1e-6) (<= r 1e-6)) (setq n-sin (1+ n-sin)))
      (setq i (1+ i))))
  (fx:log (strcat "AUDITSOBRE: " (itoa (if ss (sslength ss) 0))
    " vias | SIN sobreancho: " (itoa n-sin)))
  (close *fx-f*) (setq *fx-f* nil)
  (princ))

(defun c:FIXSOBRE (/ ss i be d nombre l r span area obj n-fix)
  (setq *fx-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/resultado.txt" "a"))
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_VIA")))) i 0 n-fix 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            d (urb:get-xdata-strings be "URB_VIA")
            nombre (urb:safe-string (nth 1 d) "VIA")
            l (atof (urb:safe-string (nth 14 d) "0"))
            r (atof (urb:safe-string (nth 15 d) "0"))
            area (atof (urb:safe-string (nth 17 d) "0"))
            span (atof (urb:safe-string (nth 18 d) "0")))
      (if (and (<= l 1e-6) (<= r 1e-6) (> span 1e-6))
        (progn
          (setq d (fx:subst-nth d 14 "1.0000"))
          (setq d (fx:subst-nth d 15 "1.0000"))
          (urb:set-xdata-strings be "URB_VIA" d)
          (setq obj (vlax-ename->vla-object be))
          (urb:set-block-attribute obj "VIA_SOBREANCHO_M2"
            (rtos (* span 2.0) 2 2))
          (urb:set-block-attribute obj "VIA_AREA_SOBREANCHO_M2"
            (rtos (+ area (* span 2.0)) 2 2))
          (fx:log (strcat "FIXSOBRE VIA " nombre " -> 1.00/1.00 | +"
            (rtos (* span 2.0) 2 1) " m2 de sobreancho"))
          (setq n-fix (1+ n-fix))))
      (setq i (1+ i))))
  (fx:log (strcat "FIXSOBRE: " (itoa n-fix) " vias corregidas"))
  (close *fx-f*) (setq *fx-f* nil)
  (princ))

;; extremos de un tramo del modelo: insercion + LONGITUD_2D + rotacion
;; (copia autocontenida de cr:tramo-ends de record2/cruce_acu_plu.lsp)
(defun fx:tramo-ends (en / ed p rot atts l)
  (setq ed (entget en))
  (setq p (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
  (setq atts (mp:att-alist en))
  (setq l (distof (mp:getval "LONGITUD_2D" atts
            (mp:getval "LONGITUD" atts "0"))))
  (if (or (null l) (<= l 0.0)) (setq l 0.0))
  (list (car p) (cadr p)
        (+ (car p) (* l (cos rot))) (+ (cadr p) (* l (sin rot))) l))

;; distancia punto-segmento 2D + proyeccion t (en metros sobre el segmento)
(defun fx:pt-seg (px py x1 y1 x2 y2 / dx dy len2 t0 cx cy len)
  (setq dx (- x2 x1) dy (- y2 y1))
  (setq len2 (+ (* dx dx) (* dy dy)) len (sqrt len2))
  (if (< len2 1e-12)
    (list (distance (list px py) (list x1 y1)) 0.0 0.0)
    (progn
      (setq t0 (/ (+ (* (- px x1) dx) (* (- py y1) dy)) len2))
      (setq cx (+ x1 (* (max 0.0 (min 1.0 t0)) dx))
            cy (+ y1 (* (max 0.0 (min 1.0 t0)) dy)))
      (list (distance (list px py) (list cx cy)) (* t0 len) len))))

;; PILOTO: partir el/los tramos ACU que pasan por encima de los
;; accesorios indicados (por ID o ETIQUETA que contenga el codigo)
(defun c:SPLITACC (/ objetivos ss i en atts id eti accs item tramos tr res
                   d tproj tlen p1 p2 pc atts2 na nb cod encontrados)
  (setq *fx-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/resultado.txt" "a"))
  (setq objetivos '("AC-500" "AC-461"))
  ;; accesorios objetivo
  (setq accs nil)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq atts (mp:att-alist en))
      (setq id (strcase (mp:getval "ID" atts ""))
            eti (strcase (mp:getval "ETIQUETA" atts "")))
      (foreach cod objetivos
        (if (or (vl-string-search cod id) (vl-string-search cod eti))
          (setq accs (cons (list cod (cdr (assoc 10 (entget en)))) accs))))
      (setq i (1+ i))))
  (fx:log (strcat "SPLITACC objetivos encontrados: " (itoa (length accs))))
  (foreach item accs
    (fx:log (strcat "  " (car item) " en ("
      (rtos (car (cadr item)) 2 1) ", " (rtos (cadr (cadr item)) 2 1) ")")))
  ;; tramos ACU
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 tramos nil)
  (if ss (while (< i (sslength ss)) (setq tramos (cons (ssname ss i) tramos)) (setq i (1+ i))))
  (setq encontrados 0)
  (foreach item accs
    (setq pc (cadr item))
    ;; buscar el tramo que PASA por el accesorio (interior, no extremo)
    (foreach en tramos
      (if (entget en)               ;; puede haber sido borrado en un split previo
        (progn
          (setq tr (fx:tramo-ends en))
          (setq res (fx:pt-seg (car pc) (cadr pc)
                      (nth 0 tr) (nth 1 tr) (nth 2 tr) (nth 3 tr)))
          (setq d (nth 0 res) tproj (nth 1 res) tlen (nth 2 res))
          (if (and (< d 0.40) (> tproj 0.60) (< tproj (- tlen 0.60)))
            (progn
              (setq p1 (list (nth 0 tr) (nth 1 tr))
                    p2 (list (nth 2 tr) (nth 3 tr)))
              (setq atts2 (vl-remove-if
                (quote (lambda (a) (member (car a)
                  (list "LONGITUD" "LONGITUD_2D" "LONGITUD_3D" "ETIQUETA"
                        "HANDLE_EXTREMO_INI" "HANDLE_EXTREMO_FIN"))))
                (mp:att-alist en)))
              (setq na (mp:insert-cant-tramo "TRAMO_ACUEDUCTO" p1
                         (list (car pc) (cadr pc)) atts2))
              (setq nb (mp:insert-cant-tramo "TRAMO_ACUEDUCTO"
                         (list (car pc) (cadr pc)) p2 atts2))
              (if (and na nb)
                (progn
                  (entdel en)
                  (foreach e2 (list na nb)
                    (mp:setatts e2 (list (cons "ETIQUETA"
                      (mp:label-tramo "TRAMO_ACUEDUCTO" (mp:att-alist e2)))))
                    (foreach a (vlax-invoke (vlax-ename->vla-object e2)
                                 (quote GetAttributes))
                      (if (= "ETIQUETA" (strcase (vla-get-TagString a)))
                        (vl-catch-all-apply (quote vla-put-Rotation) (list a 0.0)))))
                  (setq encontrados (1+ encontrados))
                  (fx:log (strcat "SPLIT " (car item) ": tramo de "
                    (rtos tlen 2 1) " m partido en "
                    (rtos tproj 2 1) " + " (rtos (- tlen tproj) 2 1) " m"))))))))))
  (fx:log (strcat "SPLITACC PILOTO: " (itoa encontrados) " tramos partidos"))
  (fx:log "FIN-SPLITACC")
  (close *fx-f*) (setq *fx-f* nil)
  (princ))
(princ "\nfix0902 listo")(princ)
