;;; cruce_acu_plu.lsp (2026-08-28) — marca CONTROL_ESTADO=EJECUTADO en
;;; acueducto y pluvial desde los records de 10_RECORD (misma convencion
;;; del cruce MT/AP/SAN del 26/08: mp:setatts -> ATTRIB+XDATA), reduce
;;; los postes de alumbrado, y arma el reporte global por disciplina.
;;; Requiere plugin cargado + rec_acu_nodes.lsp + rec_plu_data.lsp.
;;; Comandos: CRUCEACU, CRUCEPLU, FIXPOSTE, REPORTEEJEC

(defun cr:log (msg)
  (if *cr-f* (write-line msg *cr-f*))
  (princ (strcat "\n" msg)) (princ))

;; distancia punto-segmento en 2D
(defun cr:pt-seg (px py x1 y1 x2 y2 / dx dy len2 t0 cx cy)
  (setq dx (- x2 x1) dy (- y2 y1))
  (setq len2 (+ (* dx dx) (* dy dy)))
  (if (< len2 1e-12)
    (distance (list px py) (list x1 y1))
    (progn
      (setq t0 (/ (+ (* (- px x1) dx) (* (- py y1) dy)) len2))
      (if (< t0 0.0) (setq t0 0.0))
      (if (> t0 1.0) (setq t0 1.0))
      (setq cx (+ x1 (* t0 dx)) cy (+ y1 (* t0 dy)))
      (distance (list px py) (list cx cy)))))

;; extremos de un tramo del modelo: insercion + LONGITUD_2D + rotacion
(defun cr:tramo-ends (en / ed p rot atts l)
  (setq ed (entget en))
  (setq p (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
  (setq atts (mp:att-alist en))
  (setq l (distof (mp:getval "LONGITUD_2D" atts
            (mp:getval "LONGITUD" atts "0"))))
  (if (or (null l) (<= l 0.0)) (setq l 0.0))
  (list (car p) (cadr p)
        (+ (car p) (* l (cos rot))) (+ (cadr p) (* l (sin rot))) l))

(defun cr:collect (patron / ss i r)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 patron))) i 0 r nil)
  (if ss
    (while (< i (sslength ss))
      (setq r (cons (ssname ss i) r))
      (setq i (1+ i))))
  r)

;; ---------- ACUEDUCTO: ejecutado = nodos topograficos V-NODE-ACU
;; del record sobre el tramo (>=2 a menos de 2.5 m, o 1 si es corto)
(defun c:CRUCEACU (/ ents en e5 near n ml-tot ml-ej n-ej accs n-acc-ej tol)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq tol 2.5)
  (setq ents (cr:collect "MP_TRAMO_ACU_*"))
  (setq n-ej 0 ml-tot 0.0 ml-ej 0.0)
  (foreach en ents
    (setq e5 (cr:tramo-ends en))
    (setq ml-tot (+ ml-tot (nth 4 e5)))
    (setq near 0)
    (foreach nd rec:acu-nodes
      (if (< (cr:pt-seg (car nd) (cadr nd)
               (nth 0 e5) (nth 1 e5) (nth 2 e5) (nth 3 e5)) tol)
        (setq near (1+ near))))
    (if (or (>= near 2) (and (>= near 1) (< (nth 4 e5) 12.0)))
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-ej (1+ n-ej) ml-ej (+ ml-ej (nth 4 e5))))))
  (cr:log (strcat "ACU tramos: " (itoa (length ents)) " total ("
    (rtos ml-tot 2 0) " ML) | EJECUTADOS " (itoa n-ej)
    " (" (rtos ml-ej 2 0) " ML) | faltan " (itoa (- (length ents) n-ej))
    " (" (rtos (- ml-tot ml-ej) 2 0) " ML)"))
  ;; accesorios: nodo del record a menos de 2.5 m
  (setq accs (cr:collect "MP_PUNTO_ACC_ACU*"))
  (setq n-acc-ej 0)
  (foreach en accs
    (setq e5 (cdr (assoc 10 (entget en))))
    (setq near nil)
    (foreach nd rec:acu-nodes
      (if (and (not near)
               (< (distance (list (car nd) (cadr nd))
                            (list (car e5) (cadr e5))) tol))
        (setq near T)))
    (if near
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-acc-ej (1+ n-acc-ej)))))
  (cr:log (strcat "ACU accesorios: " (itoa (length accs))
    " total | EJECUTADOS " (itoa n-acc-ej)
    " | faltan " (itoa (- (length accs) n-acc-ej))))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- PLUVIAL: ejecutado = ambos extremos del tramo a <2.5 m de
;; la tuberia LLUVIAS-RECIEN-CONST; pozos a <4 m de PZ_LLUV_RC;
;; sumideros a <3 m de SUMIDERO RECIEN CONSTRUIDO
(defun cr:min-seg-dist (px py segs / d best)
  (setq best 1e9)
  (foreach s segs
    (setq d (cr:pt-seg px py (nth 0 s) (nth 1 s) (nth 2 s) (nth 3 s)))
    (if (< d best) (setq best d)))
  best)

(defun c:CRUCEPLU (/ ents en e5 n-ej ml-tot ml-ej pozos n-pz sums n-su p d)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq ents (cr:collect "MP_TRAMO_PLU_*"))
  (setq n-ej 0 ml-tot 0.0 ml-ej 0.0)
  (foreach en ents
    (setq e5 (cr:tramo-ends en))
    (setq ml-tot (+ ml-tot (nth 4 e5)))
    (if (and (< (cr:min-seg-dist (nth 0 e5) (nth 1 e5) rec:plu-segs) 2.5)
             (< (cr:min-seg-dist (nth 2 e5) (nth 3 e5) rec:plu-segs) 2.5))
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-ej (1+ n-ej) ml-ej (+ ml-ej (nth 4 e5))))))
  (cr:log (strcat "PLU tramos: " (itoa (length ents)) " total ("
    (rtos ml-tot 2 0) " ML) | EJECUTADOS " (itoa n-ej)
    " (" (rtos ml-ej 2 0) " ML) | faltan " (itoa (- (length ents) n-ej))
    " (" (rtos (- ml-tot ml-ej) 2 0) " ML)"))
  (setq pozos (cr:collect "MP_PUNTO_POZO_PLU") n-pz 0)
  (foreach en pozos
    (setq p (cdr (assoc 10 (entget en))) d 1e9)
    (foreach nd rec:plu-pozos
      (setq d (min d (distance (list (car nd) (cadr nd)) (list (car p) (cadr p))))))
    (if (< d 4.0)
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-pz (1+ n-pz)))))
  (cr:log (strcat "PLU pozos: " (itoa (length pozos))
    " total | EJECUTADOS " (itoa n-pz)
    " | faltan " (itoa (- (length pozos) n-pz))))
  (setq sums (cr:collect "MP_PUNTO_SUMIDERO") n-su 0)
  (foreach en sums
    (setq p (cdr (assoc 10 (entget en))) d 1e9)
    (foreach nd rec:plu-sumid
      (setq d (min d (distance (list (car nd) (cadr nd)) (list (car p) (cadr p))))))
    (if (< d 3.0)
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-su (1+ n-su)))))
  (cr:log (strcat "PLU sumideros: " (itoa (length sums))
    " total | EJECUTADOS " (itoa n-su)
    " | faltan " (itoa (- (length sums) n-su))))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- postes mas pequenos: editar la def EN SITIO (sin purgar,
;; contra el zombi) — circulo r=0.7, etiqueta pegada. ATTSYNC al final.
(defun c:FIXPOSTE (/ doc blks blk names bn e ed ents n)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (if (tblsearch "BLOCK" "MP_PUNTO_POSTE_ELEC")
    (progn
      (setq blk (vla-Item blks "MP_PUNTO_POSTE_ELEC"))
      ;; recolectar
      (setq ents nil)
      (vlax-for e blk (setq ents (cons e ents)))
      ;; mutar
      (setq n 0)
      (foreach e ents
        (cond
          ((= "AcDbCircle" (vlax-get-property e 'ObjectName))
            (vla-put-Radius e 0.70) (setq n (1+ n)))
          ((and (= "AcDbAttributeDefinition" (vlax-get-property e 'ObjectName))
                (= "ETIQUETA" (strcase (vla-get-TagString e))))
            (vla-put-Height e 0.50)
            (vla-put-InsertionPoint e (vlax-3d-point '(1.05 1.05 0.0)))
            (setq n (1+ n)))))
      (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" "MP_PUNTO_POSTE_ELEC"))
      (cr:log (strcat "POSTES: def MP_PUNTO_POSTE_ELEC editada ("
        (itoa n) " entidades ajustadas: circulo r=0.7, etiqueta 0.5)")))
    (cr:log "POSTES: def MP_PUNTO_POSTE_ELEC no existe"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- reporte global de TODAS las disciplinas
(defun cr:grupo (titulo patron es-tramo / ents en atts est n-ej ml ml-ej l)
  (setq ents (cr:collect patron) n-ej 0 ml 0.0 ml-ej 0.0)
  (foreach en ents
    (setq atts (mp:att-alist en))
    (setq est (strcase (mp:getval "CONTROL_ESTADO" atts "")))
    (setq l (if es-tramo
              (distof (mp:getval "LONGITUD_2D" atts (mp:getval "LONGITUD" atts "0")))
              0.0))
    (if (null l) (setq l 0.0))
    (setq ml (+ ml l))
    (if (= est "EJECUTADO")
      (setq n-ej (1+ n-ej) ml-ej (+ ml-ej l))))
  (cr:log (strcat titulo ": " (itoa (length ents)) " total"
    (if es-tramo (strcat " (" (rtos ml 2 0) " ML)") "")
    " | EJEC " (itoa n-ej)
    (if es-tramo (strcat " (" (rtos ml-ej 2 0) " ML)") "")
    " | FALTAN " (itoa (- (length ents) n-ej))
    (if es-tramo (strcat " (" (rtos (- ml ml-ej) 2 0) " ML)") ""))))

(defun c:REPORTEEJEC ()
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (cr:log "===== REPORTE GLOBAL EJECUTADO vs POR EJECUTAR =====")
  (cr:grupo "ACU tramos" "MP_TRAMO_ACU_*" T)
  (cr:grupo "ACU accesorios" "MP_PUNTO_ACC_ACU*" nil)
  (cr:grupo "SAN tramos" "MP_TRAMO_SAN_*" T)
  (cr:grupo "SAN pozos" "MP_PUNTO_POZO_SAN" nil)
  (cr:grupo "PLU tramos" "MP_TRAMO_PLU_*" T)
  (cr:grupo "PLU pozos" "MP_PUNTO_POZO_PLU" nil)
  (cr:grupo "PLU sumideros" "MP_PUNTO_SUMIDERO" nil)
  (cr:grupo "MT tramos" "MP_TRAMO_MT_*" T)
  (cr:grupo "MT+BT cajas/equipos" "MP_PUNTO_CAMARA_CS276,MP_PUNTO_CAMARA_CS280,MP_PUNTO_CAJA_BARRAJE_CS281,MP_PUNTO_SUBESTACION_E,MP_PUNTO_CDMT_E" nil)
  (cr:grupo "BTAP tramos" "MP_TRAMO_BTAP_*" T)
  (cr:grupo "AP cajas" "MP_PUNTO_CAMARA_CS274,MP_PUNTO_CAMARA_CS275,MP_PUNTO_TRANSFORMADOR_AP" nil)
  (cr:grupo "AP postes" "MP_PUNTO_POSTE_ELEC" nil)
  (cr:log "LISTO-CRUCE")
  (close *cr-f*) (setq *cr-f* nil)
  (princ))
(princ "\ncruce_acu_plu: CRUCEACU CRUCEPLU FIXPOSTE REPORTEEJEC")
(princ)

;; ---------- MT: re-marcado (las marcas del 26/08 se perdieron en los
;; tramos reconstruidos por el fix del gap esa misma noche). Ejecutado =
;; ambos extremos a <2.5 m de la red PROY del record MT (188 segmentos,
;; mismas capas del cruce original).
(defun c:CRUCEMT (/ ents en e5 n-ej ml-tot ml-ej)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq ents (cr:collect "MP_TRAMO_MT_*"))
  (setq n-ej 0 ml-tot 0.0 ml-ej 0.0)
  (foreach en ents
    (setq e5 (cr:tramo-ends en))
    (setq ml-tot (+ ml-tot (nth 4 e5)))
    (if (and (< (cr:min-seg-dist (nth 0 e5) (nth 1 e5) rec:mt-segs) 2.5)
             (< (cr:min-seg-dist (nth 2 e5) (nth 3 e5) rec:mt-segs) 2.5))
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-ej (1+ n-ej) ml-ej (+ ml-ej (nth 4 e5))))))
  (cr:log (strcat "MT tramos (re-cruce): " (itoa (length ents)) " total ("
    (rtos ml-tot 2 0) " ML) | EJECUTADOS " (itoa n-ej)
    " (" (rtos ml-ej 2 0) " ML) | faltan " (itoa (- (length ents) n-ej))
    " (" (rtos (- ml-tot ml-ej) 2 0) " ML)"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- BT/AP: RE-cruce con el record completo ajustado (offset
;; global -3000.017/-0.089 resuelto con 381 anclas caja+fotometria;
;; el cruce del 26/08 solo capturo parte). Tramo ejecutado = ambos
;; extremos a <4 m de la red record (ductos van al costado de la via);
;; caja a <2.5 m de caja record; poste a <3 m de fotometria.
(defun c:CRUCEBT (/ ents en e5 n-ej ml-tot ml-ej p d cajas n-cj postes n-po)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq ents (cr:collect "MP_TRAMO_BTAP_*"))
  (setq n-ej 0 ml-tot 0.0 ml-ej 0.0)
  (foreach en ents
    (setq e5 (cr:tramo-ends en))
    (setq ml-tot (+ ml-tot (nth 4 e5)))
    (if (and (< (cr:min-seg-dist (nth 0 e5) (nth 1 e5) rec:bt-segs) 4.0)
             (< (cr:min-seg-dist (nth 2 e5) (nth 3 e5) rec:bt-segs) 4.0))
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-ej (1+ n-ej) ml-ej (+ ml-ej (nth 4 e5))))))
  (cr:log (strcat "BTAP tramos (re-cruce): " (itoa (length ents)) " total ("
    (rtos ml-tot 2 0) " ML) | EJECUTADOS " (itoa n-ej)
    " (" (rtos ml-ej 2 0) " ML) | faltan " (itoa (- (length ents) n-ej))
    " (" (rtos (- ml-tot ml-ej) 2 0) " ML)"))
  (setq cajas (cr:collect "MP_PUNTO_CAMARA_CS274,MP_PUNTO_CAMARA_CS275,MP_PUNTO_TRANSFORMADOR_AP") n-cj 0)
  (foreach en cajas
    (setq p (cdr (assoc 10 (entget en))) d 1e9)
    (foreach nd rec:bt-cajas
      (setq d (min d (distance (list (car nd) (cadr nd)) (list (car p) (cadr p))))))
    (if (< d 2.5)
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-cj (1+ n-cj)))))
  (cr:log (strcat "AP cajas (re-cruce): " (itoa (length cajas))
    " total | EJECUTADOS " (itoa n-cj) " | faltan " (itoa (- (length cajas) n-cj))))
  (setq postes (cr:collect "MP_PUNTO_POSTE_ELEC") n-po 0)
  (foreach en postes
    (setq p (cdr (assoc 10 (entget en))) d 1e9)
    (foreach nd rec:bt-fotos
      (setq d (min d (distance (list (car nd) (cadr nd)) (list (car p) (cadr p))))))
    (if (< d 3.0)
      (progn
        (mp:setatts en (list (cons "CONTROL_ESTADO" "EJECUTADO")))
        (setq n-po (1+ n-po)))))
  (cr:log (strcat "AP postes (re-cruce): " (itoa (length postes))
    " total | EJECUTADOS " (itoa n-po) " | faltan " (itoa (- (length postes) n-po))))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- unificacion de colores por disciplina (pedido del usuario:
;; "los postes del mismo color que los tramos"): re-colorea TODAS las
;; entidades de las defs de puntos al color/capa de su red segun
;; mp:point-color/mp:point-layer. Recolectar->mutar->ATTSYNC.
(defun cr:recolor-def (defname base / doc blks blk ents e col lay)
  (if (tblsearch "BLOCK" defname)
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq blk (vla-Item (vla-get-Blocks doc) defname))
      (setq col (mp:point-color base) lay (mp:point-layer base))
      (setq ents nil)
      (vlax-for e blk (setq ents (cons e ents)))
      (foreach e ents
        (vl-catch-all-apply 'vla-put-Color (list e col))
        (vl-catch-all-apply 'vla-put-Layer (list e lay)))
      (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" defname))
      (cr:log (strcat "recoloreada " defname " -> color " (itoa col) " capa " lay))))
  (princ))

(defun c:FIXCOLORES ()
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (cr:recolor-def "MP_PUNTO_POSTE_ELEC" "POSTE_ELEC")
  (cr:recolor-def "MP_PUNTO_LUMINARIA" "LUMINARIA_AP")
  (cr:recolor-def "MP_PUNTO_TRANSFORMADOR_AP" "TRANSFORMADOR_AP")
  (cr:recolor-def "MP_PUNTO_SUMIDERO" "SUMIDERO")
  (cr:recolor-def "MP_PUNTO_POZO_SAN" "POZO_SANITARIO")
  (cr:recolor-def "MP_PUNTO_POZO_PLU" "POZO_PLUVIAL")
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- separacion VISUAL de lo ejecutado (2026-08-28, el usuario
;; no podia distinguir ejecutado/pendiente: CONTROL_ESTADO es invisible).
;; Mueve cada INSERT del modelo con CONTROL_ESTADO=EJECUTADO a la capa
;; <su-capa>-EJEC (se crea con color gris 8 para poder atenuarla o
;; apagarla y ver SOLO lo pendiente, o al reves).
(defun c:SEPARAEJEC (/ doc layers ents en atts lay novo cnt seen)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))
  (setq ents (append (cr:collect "MP_TRAMO_*") (cr:collect "MP_PUNTO_*")))
  (setq cnt 0 seen nil)
  (foreach en ents
    (setq atts (mp:att-alist en))
    (if (= (strcase (mp:getval "CONTROL_ESTADO" atts "")) "EJECUTADO")
      (progn
        (setq lay (cdr (assoc 8 (entget en))))
        (if (not (wcmatch lay "*-EJEC"))
          (progn
            (setq novo (strcat lay "-EJEC"))
            (if (not (member novo seen))
              (progn
                (if (not (tblsearch "LAYER" novo))
                  (vla-put-Color (vla-Add layers novo) 8))
                (setq seen (cons novo seen))))
            (vla-put-Layer (vlax-ename->vla-object en) novo)
            (setq cnt (1+ cnt)))))))
  (cr:log (strcat "SEPARAEJEC: " (itoa cnt) " elementos ejecutados movidos a capas -EJEC ("
    (itoa (length seen)) " capas)"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))
