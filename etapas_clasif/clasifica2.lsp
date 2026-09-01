;;; CLASIFICA2 (2026-09-01): clasificacion por PUNTO-EN-POLIGONO con las
;;; zonas reales (BOUNDARY de SUBETAPAS); fallback rotulo mas cercano
;;; solo para puntos fuera de todo poligono. SOBREESCRIBE la
;;; clasificacion anterior (que era por rotulo y fallaba en bordes).
(defun c2:in-poly (px py pts / n i j xi yi xj yj dentro)
  (setq n (length pts) i 0 j (1- n) dentro nil)
  (while (< i n)
    (setq xi (car (nth i pts)) yi (cadr (nth i pts))
          xj (car (nth j pts)) yj (cadr (nth j pts)))
    (if (and (/= (> yi py) (> yj py))
             (< px (+ xi (/ (* (- xj xi) (- py yi)) (- yj yi)))))
      (setq dentro (not dentro)))
    (setq j i i (1+ i)))
  dentro)
(defun c2:zona (p / z item)
  (setq z nil)
  (foreach item eta:zonas
    (if (and (not z) (c2:in-poly (car p) (cadr p) (cdr item)))
      (setq z (car item))))
  ;; fallback: rotulo mas cercano
  (if (null z)
    (progn
      (setq bd 1e9)
      (foreach item eta:labels
        (setq d (distance (list (cadr item) (caddr item)) p))
        (if (< d bd) (setq bd d z (car item))))))
  z)
(defun c2:etapa-de (cod / i c dig)
  (setq dig "" i 1)
  (while (and (<= i (strlen cod))
              (wcmatch (setq c (substr cod i 1)) "[0-9]"))
    (setq dig (strcat dig c)) (setq i (1+ i)))
  dig)
(defun c:CLASIFICA2 (/ f ss i en ed p cod eta sub n dist v k ents cambio
                       atts prev)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/clasifica2.txt" "w"))
  (setq ss (ssget "_X" (list (cons 0 "INSERT")
            (cons 2 "MP_TRAMO_*,MP_PUNTO_*,URB_VIA_*,URB_SENDERO_*"))))
  (setq ents nil i 0)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (setq n 0 cambio 0 dist nil)
  (foreach en ents
    (setq ed (entget en) p (cdr (assoc 10 ed)))
    (setq cod (c2:zona (list (car p) (cadr p))))
    (setq eta (c2:etapa-de cod))
    (setq sub (if (> (strlen cod) (strlen eta)) cod ""))
    (setq atts (mp:att-alist en))
    (setq prev (mp:getval "SUBETAPA" atts (mp:getval "ETAPA" atts "")))
    (mp:setatts en (list (cons "ETAPA" eta)
      (cons "SUBETAPA" (if (= sub "") eta sub))))
    (setq n (1+ n))
    (if (/= prev (if (= sub "") eta sub)) (setq cambio (1+ cambio)))
    (setq k (if (= sub "") eta sub))
    (setq v (assoc k dist))
    (setq dist (if v (subst (cons k (1+ (cdr v))) v dist) (cons (cons k 1) dist))))
  (write-line (strcat "CLASIFICA2: " (itoa n) " clasificados por poligono, "
    (itoa cambio) " CAMBIARON vs la clasificacion anterior") f)
  (foreach v (vl-sort dist (quote (lambda (a b) (> (cdr a) (cdr b)))))
    (write-line (strcat "  " (car v) ": " (itoa (cdr v))) f))
  (write-line "FIN-CLASIFICA2" f)
  (close f)
  (princ))
(princ "\nCLASIFICA2 listo")(princ)

;;; CLASIFICA3 (2026-09-01): anclas por MANZANA. Cada rotulo de lote
;;; (L##/PQ##/PL#/E#, 76 en total) hereda la subetapa de su rotulo de
;;; ETAPA vecino (ambos en el centro de la zona); cada elemento toma la
;;; subetapa del ancla de lote MAS CERCANA. La frontera efectiva queda
;;; en el eje de la via entre manzanas (la regla real del plano de
;;; etapas), sin depender de poligonos.
(defun c3:mapa-lotes (/ out item best bd d lab)
  (setq out nil)
  (foreach item eta:lotes
    (setq best nil bd 1e9)
    (foreach lab eta:labels
      (setq d (distance (list (cadr item) (caddr item))
                        (list (cadr lab) (caddr lab))))
      (if (< d bd) (setq bd d best lab)))
    (setq out (cons (list (car item) (cadr item) (caddr item)
                          (car best) bd) out)))
  out)
(defun c:CLASIFICA3 (/ f mapa ss i en ed p best bd d item cod eta sub n
                       cambio dist v k ents atts prev)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/clasifica3.txt" "w"))
  (setq mapa (c3:mapa-lotes))
  (write-line "--- mapa lote -> subetapa (dist rotulo-rotulo) ---" f)
  (foreach item mapa
    (write-line (strcat "  " (car item) " -> " (nth 3 item)
      " (" (rtos (nth 4 item) 2 0) " m)") f))
  (setq ss (ssget "_X" (list (cons 0 "INSERT")
            (cons 2 "MP_TRAMO_*,MP_PUNTO_*,URB_VIA_*,URB_SENDERO_*"))))
  (setq ents nil i 0)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (setq n 0 cambio 0 dist nil)
  (foreach en ents
    (setq ed (entget en) p (cdr (assoc 10 ed)))
    (setq best nil bd 1e9)
    (foreach item mapa
      (setq d (distance (list (cadr item) (caddr item))
                        (list (car p) (cadr p))))
      (if (< d bd) (setq bd d best item)))
    (setq cod (nth 3 best))
    (setq eta "" )
    (setq i 1)
    (while (and (<= i (strlen cod))
                (wcmatch (substr cod i 1) "[0-9]"))
      (setq eta (strcat eta (substr cod i 1)))
      (setq i (1+ i)))
    (setq sub (if (> (strlen cod) (strlen eta)) cod eta))
    (setq atts (mp:att-alist en))
    (setq prev (mp:getval "SUBETAPA" atts ""))
    (mp:setatts en (list (cons "ETAPA" eta) (cons "SUBETAPA" sub)))
    (setq n (1+ n))
    (if (/= prev sub) (setq cambio (1+ cambio)))
    (setq v (assoc sub dist))
    (setq dist (if v (subst (cons sub (1+ (cdr v))) v dist) (cons (cons sub 1) dist))))
  (write-line (strcat "CLASIFICA3: " (itoa n) " clasificados por ancla de manzana, "
    (itoa cambio) " CAMBIARON") f)
  (foreach v (vl-sort dist (quote (lambda (a b) (> (cdr a) (cdr b)))))
    (write-line (strcat "  " (car v) ": " (itoa (cdr v))) f))
  (write-line "FIN-CLASIFICA3" f)
  (close f)
  (princ))
