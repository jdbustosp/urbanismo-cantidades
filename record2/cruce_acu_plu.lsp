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

;; ---------- vista "solo lo pendiente": apagar+congelar las capas -EJEC
(defun c:APAGAEJEC (/ doc lay n)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) n 0)
  (vlax-for lay (vla-get-Layers doc)
    (if (wcmatch (strcase (vla-get-Name lay)) "*-EJEC")
      (progn
        (vl-catch-all-apply 'vla-put-LayerOn (list lay :vlax-false))
        (vl-catch-all-apply 'vla-put-Freeze (list lay :vlax-true))
        (setq n (1+ n)))))
  (cr:log (strcat "APAGAEJEC: " (itoa n) " capas -EJEC apagadas y congeladas (solo queda visible lo POR EJECUTAR)"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- color de vias: URB-VIA a gris 8 (era amarillo 2 = igual al
;; alumbrado BT; todo en la via es ByLayer asi que cambia entera)
(defun c:RECOLORVIA (/ doc lay)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (tblsearch "LAYER" "URB-VIA")
    (progn
      (vla-put-Color (vla-Item (vla-get-Layers doc) "URB-VIA") 8)
      (cr:log "RECOLORVIA: capa URB-VIA -> color 8 (gris pavimento)"))
    (cr:log "RECOLORVIA: no existe URB-VIA"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- auditoria de movimiento de tierras de vias: por cada via
;; URB_VIA_* lee el xdata URB_VIA (nombre 1, etapa 2, estado 19,
;; corte 23, relleno 24, area 17, longitud 18) y reporta completitud
(defun c:AUDITMOV (/ ss i en data nom eta est corte rell area lng
                     n-tot n-mov n-cero n-sin tot-c tot-r msgs)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/audit_mov.txt" "w"))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "URB_VIA_*"))))
  (setq i 0 n-tot 0 n-mov 0 n-cero 0 n-sin 0 tot-c 0.0 tot-r 0.0 msgs nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq data (urb:get-xdata-strings en "URB_VIA"))
      (if data
        (progn
          (setq n-tot (1+ n-tot))
          (setq nom (urb:safe-string (nth 1 data) "?")
                eta (urb:safe-string (nth 2 data) "?")
                est (urb:safe-string (if (> (length data) 19) (nth 19 data) "") "")
                corte (atof (urb:safe-string (if (> (length data) 23) (nth 23 data) "0") "0"))
                rell (atof (urb:safe-string (if (> (length data) 24) (nth 24 data) "0") "0"))
                area (atof (urb:safe-string (if (> (length data) 17) (nth 17 data) "0") "0"))
                lng (atof (urb:safe-string (if (> (length data) 18) (nth 18 data) "0") "0")))
          (cond
            ((/= est "MOVIMIENTO DE TIERRAS CALCULADO")
              (setq n-sin (1+ n-sin))
              (setq msgs (cons (strcat "  SIN MOVIMIENTO: " nom " (etapa " eta
                ", area " (rtos area 2 0) " m2)") msgs)))
            ((and (< corte 0.01) (< rell 0.01))
              (setq n-cero (1+ n-cero))
              (setq msgs (cons (strcat "  MOV EN CERO: " nom " (etapa " eta
                ", area " (rtos area 2 0) " m2, L " (rtos lng 2 0) " m)") msgs)))
            (T
              (setq n-mov (1+ n-mov))
              (setq tot-c (+ tot-c corte) tot-r (+ tot-r rell))))))
      (setq i (1+ i))))
  (cr:log (strcat "AUDITORIA MOVIMIENTO DE TIERRAS: " (itoa n-tot) " vias | "
    (itoa n-mov) " con corte/relleno OK (corte total " (rtos tot-c 2 0)
    " m3, relleno total " (rtos tot-r 2 0) " m3) | "
    (itoa n-cero) " en cero | " (itoa n-sin) " sin calcular"))
  (foreach m (reverse msgs) (cr:log m))
  (cr:log "FIN-AUDITMOV")
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- rediseno visual de tramos ACU existentes (2026-08-28):
;; tuberia delgada 0.20 (era franja de 2.0), etiqueta compacta 0.60
;; ("Ø8" PVC L=34"), sin PENDIENTE_VIS (red a presion). Edita las defs
;; MP_TRAMO_ACU_* EN SITIO (sin purgar) + ATTSYNC + reescribe la
;; ETIQUETA de cada insert. Recolectar->mutar->verificar.
(defun c:REDISENOACU (/ doc blks names bn blk ents e ty n-def ss i en atts
                        n-lab espan)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  ;; 1) recolectar nombres de defs
  (setq names nil)
  (vlax-for blk blks
    (if (wcmatch (strcase (vla-get-Name blk)) "MP_TRAMO_ACU_*")
      (setq names (cons (vla-get-Name blk) names))))
  ;; 2) mutar cada def: polilinea 0.20 (largo completo), ETIQUETA 0.60
  ;;    reposicionada, PENDIENTE_VIS eliminada
  (setq n-def 0)
  (foreach bn names
    (setq blk (vla-Item blks bn))
    (setq espan (mp:block-tramo-length blk))
    (setq ents nil)
    (vlax-for e blk (setq ents (cons e ents)))
    (foreach e ents
      (setq ty (vla-get-ObjectName e))
      (cond
        ((= ty "AcDbPolyline")
          (vla-put-ConstantWidth e 0.20)
          (if (> espan 1e-9)
            (vla-put-Coordinates e (mp:var-dbls (list 0.0 0.0 espan 0.0)))))
        ((and (= ty "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString e)) "ETIQUETA"))
          (vla-put-Height e 0.60)
          (vla-put-InsertionPoint e
            (vlax-3d-point (list (/ espan 2.0) 0.81 0.0)))
          (vla-put-Alignment e acAlignmentMiddleCenter)
          (vla-put-TextAlignmentPoint e
            (vlax-3d-point (list (/ espan 2.0) 0.81 0.0))))
        ((and (= ty "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString e)) "PENDIENTE_VIS"))
          (urb:safe-delete e))))
    (setq n-def (1+ n-def)))
  ;; 3) ATTSYNC por def (fuera de los vlax-for)
  (foreach bn names
    (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bn)))
  (cr:log (strcat "REDISENOACU: " (itoa n-def) " defs de tramo ACU rediseñadas"))
  ;; 4) reescribir ETIQUETA compacta por insert
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_ACU_*"))) i 0 n-lab 0)
  (setq ents nil)
  (if ss
    (while (< i (sslength ss))
      (setq ents (cons (ssname ss i) ents))
      (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (mp:setatts en (list (cons "ETIQUETA"
      (mp:label-tramo "TRAMO_ACUEDUCTO" atts))))
    (setq n-lab (1+ n-lab)))
  (cr:log (strcat "REDISENOACU: " (itoa n-lab) " etiquetas de tramo reescritas"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- claridad general de redes hidro (2026-08-28, 2a revision
;; del usuario): SAN/PLU delgados 0.20 con textos 0.60, ACU recortado
;; 2.0 en las puntas (no tapar simbolos), etiquetas de pozos/sumideros
;; a 0.75, y etiquetas de accesorios HORIZONTALES (quedaban rotadas con
;; el simbolo). Recolectar->mutar->ATTSYNC->rotacion.
(defun rh:span-de (bn / p)
  ;; largo del tramo desde el nombre MP_TRAMO_XXX_<NN_NN>
  (setq p (vl-string-position (ascii "_") bn (- (strlen bn) 12)))
  (mp:block-tramo-length (vla-Item (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))) bn)))

(defun c:REDISENOHIDRO (/ doc blks names bn blk ents e ty espan cut n-def
                          ss i en atts n-rot att)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  ;; 1) defs de tramos SAN/PLU/ACU
  (setq names nil)
  (vlax-for blk blks
    (if (wcmatch (strcase (vla-get-Name blk)) "MP_TRAMO_SAN_*,MP_TRAMO_PLU_*,MP_TRAMO_ACU_*")
      (setq names (cons (vla-get-Name blk) names))))
  (setq n-def 0)
  (foreach bn names
    (setq blk (vla-Item blks bn))
    (setq espan (mp:block-tramo-length blk))
    (setq cut (if (wcmatch (strcase bn) "MP_TRAMO_ACU_*")
                (min 2.0 (/ espan 4.0)) 0.0))
    (setq ents nil)
    (vlax-for e blk (setq ents (cons e ents)))
    (foreach e ents
      (setq ty (vla-get-ObjectName e))
      (cond
        ((= ty "AcDbPolyline")
          (vla-put-ConstantWidth e 0.20)
          (if (> espan 1e-9)
            (vla-put-Coordinates e
              (mp:var-dbls (list cut 0.0 (- espan cut) 0.0)))))
        ((and (= ty "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString e)) "ETIQUETA"))
          (vla-put-Height e 0.60)
          (vla-put-InsertionPoint e (vlax-3d-point (list (/ espan 2.0) 0.81 0.0)))
          (vla-put-Alignment e acAlignmentMiddleCenter)
          (vla-put-TextAlignmentPoint e (vlax-3d-point (list (/ espan 2.0) 0.81 0.0))))
        ((and (= ty "AcDbAttributeDefinition")
              (= (strcase (vla-get-TagString e)) "PENDIENTE_VIS"))
          (vla-put-Height e 0.60)
          (vla-put-InsertionPoint e (vlax-3d-point (list (/ espan 2.0) -0.81 0.0)))
          (vla-put-Alignment e acAlignmentMiddleCenter)
          (vla-put-TextAlignmentPoint e (vlax-3d-point (list (/ espan 2.0) -0.81 0.0))))))
    (setq n-def (1+ n-def)))
  ;; 2) etiquetas de pozos/sumideros a 0.75
  (foreach bn '("MP_PUNTO_POZO_SAN" "MP_PUNTO_POZO_PLU" "MP_PUNTO_SUMIDERO")
    (if (tblsearch "BLOCK" bn)
      (progn
        (setq blk (vla-Item blks bn) ents nil)
        (vlax-for e blk (setq ents (cons e ents)))
        (foreach e ents
          (if (and (= "AcDbAttributeDefinition" (vla-get-ObjectName e))
                   (= "ETIQUETA" (strcase (vla-get-TagString e))))
            (vla-put-Height e 0.75)))
        (setq names (cons bn names)))))
  ;; 3) ATTSYNC de todo lo tocado (fuera de los vlax-for)
  (foreach bn names
    (vl-catch-all-apply 'vl-cmdf (list "_.ATTSYNC" "_N" bn)))
  (cr:log (strcat "REDISENOHIDRO: " (itoa n-def) " defs de tramo + pozos/sumideros, ATTSYNC en " (itoa (length names))))
  ;; 4) etiquetas de ACCESORIOS horizontales (los inserts quedaron
  ;;    rotados al plano y el texto giro con ellos) -- DESPUES de todo
  ;;    attsync; rotacion absoluta 0 del ATTRIB
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU*"))) i 0 n-rot 0)
  (setq ents nil)
  (if ss
    (while (< i (sslength ss))
      (setq ents (cons (ssname ss i) ents))
      (setq i (1+ i))))
  (foreach en ents
    (foreach att (vlax-invoke (vlax-ename->vla-object en) 'GetAttributes)
      (if (= "ETIQUETA" (strcase (vla-get-TagString att)))
        (progn
          (vl-catch-all-apply 'vla-put-Rotation (list att 0.0))
          (setq n-rot (1+ n-rot))))))
  (cr:log (strcat "REDISENOHIDRO: " (itoa n-rot) " etiquetas de accesorio puestas horizontales"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

;; ---------- 3a revision (2026-08-28 tarde): reparar el doble recorte
;; de ACU (largo real desde el NOMBRE del bloque, motor >=4.62.2),
;; etiquetas fuera en tramos ACU <8m, borrar los 11 tramos PLU bogus
;; que atraviesan el proyecto, y crear los cabezales pluviales del plano.
(defun c:REPARAACU3 (/ doc blks names bn blk ents e ty espan cut n-def
                       ss i en atts n-lab)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq names nil)
  (vlax-for blk blks
    (if (wcmatch (strcase (vla-get-Name blk)) "MP_TRAMO_ACU_*")
      (setq names (cons (vla-get-Name blk) names))))
  (setq n-def 0)
  (foreach bn names
    (setq blk (vla-Item blks bn))
    ;; largo VERDADERO desde el nombre (inmutable, idempotente)
    (setq espan (mp:tramo-span-from-name bn))
    (if (> espan 1e-9)
      (progn
        (setq cut (min 1.0 (* 0.15 espan)))
        (setq ents nil)
        (vlax-for e blk (setq ents (cons e ents)))
        (foreach e ents
          (if (= "AcDbPolyline" (vla-get-ObjectName e))
            (progn
              (vla-put-ConstantWidth e 0.20)
              (vla-put-Coordinates e
                (mp:var-dbls (list cut 0.0 (- espan cut) 0.0))))))
        (setq n-def (1+ n-def)))))
  (cr:log (strcat "REPARAACU3: " (itoa n-def) " defs re-cortadas desde el largo del nombre"))
  ;; etiquetas: "" en tramos <8m, compacta en el resto
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_ACU_*"))) i 0 n-lab 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (foreach en ents
    (setq atts (mp:att-alist en))
    (mp:setatts en (list (cons "ETIQUETA" (mp:label-tramo "TRAMO_ACUEDUCTO" atts))))
    (setq n-lab (1+ n-lab)))
  (cr:log (strcat "REPARAACU3: " (itoa n-lab) " etiquetas actualizadas (cortos sin texto)"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

(defun c:BORRAPLUBOGUS (/ handles h en ed n)
  ;; 11 tramos PLU con longitudes 105-679 m que cruzan el proyecto en
  ;; diagonal (conexiones erroneas detectadas 2026-08-28); verificados
  ;; por handle Y por nombre de bloque antes de borrar.
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq handles '("52D26" "52402" "5225E" "521AA" "51CDF" "51A87"
                  "50A9B" "509E7" "508F7" "5078F" "50627"))
  (setq n 0)
  (foreach h handles
    (setq en (handent h))
    (if (and en (setq ed (entget en))
             (= "INSERT" (cdr (assoc 0 ed)))
             (wcmatch (strcase (cdr (assoc 2 ed))) "MP_TRAMO_PLU_*"))
      (progn (entdel en) (setq n (1+ n)))
      (cr:log (strcat "  BORRAPLUBOGUS: handle " h " no coincide, omitido"))))
  (cr:log (strcat "BORRAPLUBOGUS: " (itoa n) "/11 tramos PLU bogus eliminados"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))

(defun c:CREACABEZALES (/ done p rot item cerca d en n obj vals i)
  ;; crea los cabezales del plano (dedupe <0.1 m: el plano los tiene
  ;; por pares duplicados exactos)
  (setq *cr-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/cruce_result.txt" "a"))
  (setq done nil n 0 i 0)
  (foreach item cab:ins
    (setq p (list (car item) (cadr item)) rot (caddr item))
    (setq cerca nil)
    (foreach d done
      (if (and (not cerca) (< (distance d p) 0.1)) (setq cerca T)))
    (if (not cerca)
      (progn
        (setq done (cons p done) i (1+ i))
        (setq vals (list
          (cons "RED" "PLUVIAL")
          (cons "ID" (strcat "CAB-" (if (< i 10) "0" "") (itoa i)))
          (cons "ORIGEN_CREACION" "LOTE_CABEZALES_20260828")))
        (setq en (mp:insert-cant-point "CABEZAL_PLUVIAL" p vals))
        (if en
          (progn
            (setq obj (vlax-ename->vla-object en))
            (vl-catch-all-apply 'vla-put-Rotation
              (list obj (* pi (/ rot 180.0))))
            (setq n (1+ n)))))))
  (cr:log (strcat "CREACABEZALES: " (itoa n) " cabezales creados (de "
    (itoa (length cab:ins)) " inserts del plano, duplicados depurados)"))
  (close *cr-f*) (setq *cr-f* nil)
  (princ))
