;; CRUCE RECORD AP + SANITARIO (2026-08-26): marca CONTROL_ESTADO=
;; EJECUTADO en el modelo segun los as-built de 10_RECORD.
;; El record BT esta trasladado EXACTAMENTE +3000 en X (verificado a
;; 0.0001 m) -> se aplica dx=-3000. El sanitario esta en coordenadas.
(vl-load-com)
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")
(defun c2:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/cruce_record2_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c2:d-seg (p a b / ax ay bx by px py dx dy t2 qx qy)
  (setq ax (car a) ay (cadr a) bx (car b) by (cadr b)
        px (car p) py (cadr p) dx (- bx ax) dy (- by ay))
  (setq t2 (+ (* dx dx) (* dy dy)))
  (if (< t2 1e-9)
    (sqrt (+ (expt (- px ax) 2) (expt (- py ay) 2)))
    (progn
      (setq t2 (max 0.0 (min 1.0
        (/ (+ (* (- px ax) dx) (* (- py ay) dy)) t2))))
      (setq qx (+ ax (* t2 dx)) qy (+ ay (* t2 dy)))
      (sqrt (+ (expt (- px qx) 2) (expt (- py qy) 2))))))

;; marca puntos del modelo contra puntos del record
(defun c2:marca-puntos (patron ptsrec tol nombre / ss n i e ip bd best d ejec falt)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 patron))))
  (setq n (if ss (sslength ss) 0) i 0 ejec 0 falt 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ip (cdr (assoc 10 (entget e))))
    (setq bd tol best nil)
    (foreach p ptsrec
      (setq d (sqrt (+ (expt (- (car p) (car ip)) 2)
                       (expt (- (cadr p) (cadr ip)) 2))))
      (if (< d bd) (setq bd d best p)))
    (if best
      (progn
        (vl-catch-all-apply 'mp:setatt-one (list e "CONTROL_ESTADO" "EJECUTADO"))
        (setq ejec (1+ ejec)))
      (setq falt (1+ falt)))
    (setq i (1+ i)))
  (c2:log (strcat nombre ": " (itoa ejec) " EJECUTADOS / " (itoa falt)
    " por ejecutar (de " (itoa n) ")")))

;; marca tramos del modelo contra segmentos del record
(defun c2:marca-tramos (patron pref segs nombre / ss n i e ed ip rot distv lng
                        sub sd okpts j tt mx my bd d ejec falt ml-e ml-f)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 patron))))
  (setq n (if ss (sslength ss) 0) i 0 ejec 0 falt 0 ml-e 0.0 ml-f 0.0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq ed (entget e))
    (setq ip (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
    (setq distv (atof (vl-string-translate "_" "."
      (substr (cdr (assoc 2 ed))
        (+ (strlen pref) 1 (vl-string-search pref (cdr (assoc 2 ed))))))))
    (setq lng distv sub (entnext e))
    (while (and sub (/= (cdr (assoc 0 (entget sub))) "SEQEND"))
      (setq sd (entget sub))
      (if (and (= (cdr (assoc 0 sd)) "ATTRIB")
               (= (cdr (assoc 2 sd)) "LONGITUD"))
        (setq lng (atof (cdr (assoc 1 sd)))))
      (setq sub (entnext sub)))
    (setq okpts 0 j 1)
    (while (<= j 5)
      (setq tt (/ j 6.0))
      (setq mx (+ (car ip) (* tt distv (cos rot)))
            my (+ (cadr ip) (* tt distv (sin rot))))
      (setq bd 2.5)
      (foreach s segs
        (setq d (c2:d-seg (list mx my) (car s) (cadr s)))
        (if (< d bd) (setq bd d)))
      (if (< bd 2.5) (setq okpts (1+ okpts)))
      (setq j (1+ j)))
    (if (>= okpts 3)
      (progn
        (vl-catch-all-apply 'mp:setatt-one (list e "CONTROL_ESTADO" "EJECUTADO"))
        (setq ejec (1+ ejec) ml-e (+ ml-e lng)))
      (setq falt (1+ falt) ml-f (+ ml-f lng)))
    (setq i (1+ i)))
  (c2:log (strcat nombre ": " (itoa ejec) " EJECUTADOS (" (rtos ml-e 2 1)
    " ML) / " (itoa falt) " por ejecutar (" (rtos ml-f 2 1) " ML) de " (itoa n))))

(defun c2:carga (archivo dx / f lin parts p pts ptsc segs lums i)
  ;; devuelve (puntos segmentos luminarias)
  (setq ptsc nil segs nil lums nil)
  (setq f (open (strcat lr:dir archivo) "r"))
  (while (setq lin (read-line f))
    (setq parts (lr:split lin "|"))
    (cond
      ((member (car parts) '("CAJA" "POZO"))
        (setq p (lr:parse-pt (caddr parts)))
        (if p (setq ptsc (cons (list (+ (car p) dx) (cadr p)) ptsc))))
      ((= (car parts) "LUMR")
        (setq p (lr:parse-pt (caddr parts)))
        (if p (setq lums (cons (list (+ (car p) dx) (cadr p)) lums))))
      ((= (car parts) "TRAMO")
        (setq pts (lr:parse-pts (caddr parts)))
        (setq pts (mapcar '(lambda (q) (list (+ (car q) dx) (cadr q))) pts))
        (setq i 0)
        (while (< (1+ i) (length pts))
          (setq segs (cons (list (nth i pts) (nth (1+ i) pts)) segs))
          (setq i (1+ i))))))
  (close f)
  (list ptsc segs lums))

(defun c:CRUCERECORD2 (/ bt res)
  (c2:log "== CRUCE RECORD AP + SANITARIO ==")
  (setq bt (c2:carga "data_RECORD_BT.txt" -3000.0))
  (c2:log (strcat "Record BT (dx=-3000): " (itoa (length (car bt))) " cajas, "
    (itoa (length (cadr bt))) " segmentos, " (itoa (length (caddr bt))) " luminarias"))
  (setq res (c2:carga "data_RECORD_RES.txt" 0.0))
  (c2:log (strcat "Record RES: " (itoa (length (car res))) " pozos, "
    (itoa (length (cadr res))) " segmentos"))
  ;; --- ALUMBRADO
  (c2:marca-puntos "MP_PUNTO_CAMARA_CS274,MP_PUNTO_CAMARA_CS275,MP_PUNTO_TRANSFORMADOR*"
    (car bt) 1.5 "CAJAS/TRAFOS AP")
  (c2:marca-tramos "MP_TRAMO_BTAP_*" "BTAP_" (cadr bt) "TRAMOS AP")
  (c2:marca-puntos "MP_PUNTO_POSTE*" (caddr bt) 7.0 "POSTES AP (por luminaria ejecutada)")
  ;; --- SANITARIO
  (c2:marca-puntos "MP_PUNTO_POZO_SAN*" (car res) 2.5 "POZOS SANITARIOS")
  (c2:marca-tramos "MP_TRAMO_SAN_*" "SAN_" (cadr res) "TRAMOS SANITARIOS")
  (c2:log "== CRUCERECORD2-TERMINADO ==")
  (princ))
(c:CRUCERECORD2)
