;; CRUCE RECORD MT (2026-08-26): contrasta lo EJECUTADO (as-built
;; 10_RECORD Red Media Tension) contra el modelo MT proyectado del
;; master. Marca CONTROL_ESTADO=EJECUTADO (via XDATA del plugin) en
;; cajas y tramos que coinciden con el record, y reporta que falta.
(vl-load-com)
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")
(defun cr:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/cruce_record_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

;; distancia punto-segmento
(defun cr:d-seg (p a b / ax ay bx by px py dx dy t2 qx qy)
  (setq ax (car a) ay (cadr a) bx (car b) by (cadr b)
        px (car p) py (cadr p)
        dx (- bx ax) dy (- by ay))
  (setq t2 (+ (* dx dx) (* dy dy)))
  (if (< t2 1e-9)
    (sqrt (+ (expt (- px ax) 2) (expt (- py ay) 2)))
    (progn
      (setq t2 (/ (+ (* (- px ax) dx) (* (- py ay) dy)) t2))
      (setq t2 (max 0.0 (min 1.0 t2)))
      (setq qx (+ ax (* t2 dx)) qy (+ ay (* t2 dy)))
      (sqrt (+ (expt (- px qx) 2) (expt (- py qy) 2))))))

(defun c:CRUCERECORD (/ f lin parts pts cajas segs i j p a b ss n e ed ip rot
                      distv mx my best bd d cnt ejec falt ml-e ml-f lng
                      atts sub sd okpts tt id)
  (cr:log "== CRUCE RECORD MT ==")
  (setq cajas nil segs nil)
  (setq f (open (strcat lr:dir "data_RECORD_MT.txt") "r"))
  (while (setq lin (read-line f))
    (setq parts (lr:split lin "|"))
    (cond
      ((= (car parts) "CAJA")
        (setq p (lr:parse-pt (nth 3 parts)))
        (if p (setq cajas (cons p cajas))))
      ((= (car parts) "TRAMO")
        (setq pts (lr:parse-pts (caddr parts)))
        (setq i 0)
        (while (< (1+ i) (length pts))
          (setq segs (cons (list (nth i pts) (nth (1+ i) pts)) segs))
          (setq i (1+ i))))))
  (close f)
  (cr:log (strcat "Record: " (itoa (length cajas)) " cajas ejecutadas, "
    (itoa (length segs)) " segmentos de canalizacion ejecutada"))
  ;; ---- cajas del modelo
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CAMARA_CS276,MP_PUNTO_CAMARA_CS280"))))
  (setq n (if ss (sslength ss) 0) i 0 ejec 0 falt 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ip (cdr (assoc 10 (entget e))))
    (setq bd 1.5 best nil)
    (foreach p cajas
      (setq d (sqrt (+ (expt (- (car p) (car ip)) 2)
                       (expt (- (cadr p) (cadr ip)) 2))))
      (if (< d bd) (setq bd d best p)))
    (if best
      (progn
        (vl-catch-all-apply 'mp:setatt-one (list e "CONTROL_ESTADO" "EJECUTADO"))
        (setq ejec (1+ ejec)))
      (setq falt (1+ falt)))
    (setq i (1+ i)))
  (cr:log (strcat "CAJAS MT: " (itoa ejec) " EJECUTADAS / " (itoa falt)
    " por ejecutar (de " (itoa n) " proyectadas)"))
  ;; ---- tramos del modelo (5 puntos muestreados sobre el eje)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_MT_*"))))
  (setq n (if ss (sslength ss) 0) i 0 ejec 0 falt 0 ml-e 0.0 ml-f 0.0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ed (entget e))
    (setq ip (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
    (setq distv (atof (vl-string-translate "_" "."
      (substr (cdr (assoc 2 ed)) (+ 4 (vl-string-search "MT_" (cdr (assoc 2 ed))))))))
    ;; longitud de ppto del atributo
    (setq lng distv sub (entnext e) id "")
    (while (and sub (/= (cdr (assoc 0 (entget sub))) "SEQEND"))
      (setq sd (entget sub))
      (if (= (cdr (assoc 0 sd)) "ATTRIB")
        (progn
          (if (= (cdr (assoc 2 sd)) "LONGITUD")
            (setq lng (atof (cdr (assoc 1 sd)))))))
      (setq sub (entnext sub)))
    (setq okpts 0 j 1)
    (while (<= j 5)
      (setq tt (/ j 6.0))
      (setq mx (+ (car ip) (* tt distv (cos rot)))
            my (+ (cadr ip) (* tt distv (sin rot))))
      (setq bd 2.5)
      (foreach s segs
        (setq d (cr:d-seg (list mx my) (car s) (cadr s)))
        (if (< d bd) (setq bd d)))
      (if (< bd 2.5) (setq okpts (1+ okpts)))
      (setq j (1+ j)))
    (if (>= okpts 3)
      (progn
        (vl-catch-all-apply 'mp:setatt-one (list e "CONTROL_ESTADO" "EJECUTADO"))
        (setq ejec (1+ ejec) ml-e (+ ml-e lng)))
      (setq falt (1+ falt) ml-f (+ ml-f lng)))
    (setq i (1+ i)))
  (cr:log (strcat "TRAMOS MT: " (itoa ejec) " EJECUTADOS ("
    (rtos ml-e 2 1) " ML) / " (itoa falt) " por ejecutar ("
    (rtos ml-f 2 1) " ML) de " (itoa n)))
  (cr:log "== CRUCERECORD-TERMINADO ==")
  (princ))
(c:CRUCERECORD)
