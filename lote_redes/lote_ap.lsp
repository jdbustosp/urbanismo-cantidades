;; LOTE ALUMBRADO v2 (2026-08-26): remodela el AP desde los datos REALES
;; de los bloques CR T1..T5 de SERIE 6 (data_AP_CRT.txt):
;;   FASE A: borra el AP anterior (603 luminarias por texto + 553 tramos
;;     encadenados, que quedaron corridos). SIN purgar defs (anti-zombi).
;;   FASE B: 632 cajas AP-274 + 16 CS-275 (posicion+rotacion del plano).
;;   FASE C: 5 transformadores pedestal.
;;   FASE D: 634 tramos de caja a caja sobre la red 0_0 RED BT SUBT PROY,
;;     con ductos y LONGITUD del d= del plano cuando la etiqueta valida.
;;   FASE E: postes (PC10/PC12/PM14/combos RALED+PC) con SUS luminarias
;;     (cantidad + referencia) asignadas por cercania.
;;   FASE F: reparacion de defs BTAP reutilizadas (franja 0.20 completa,
;;     LONG_VIS) + etiquetas de instancia.
(vl-load-com)
(load "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/lote_redes.lsp")

(defun la:log (m / f)
  (setq f (open (strcat lr:dir "lote_ap_log.txt") "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun la:caja (base pt rot id circ / obj a hh)
  (mp:insert-cant-point base pt
    (list (cons "ID" id) (cons "TIPO_CAJA" (mp:tipo-caja-de base))
          (cons "CIRCUITO_AP" circ)))
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
          (list a (mp:3d (list (car pt) (- (cadr pt) hh 0.5) 0.0)))))))
  (entlast))

(defun la:altura-de (nom)
  (cond
    ((vl-string-search "PC12" nom) "12")
    ((vl-string-search "PM14" nom) "14")
    ((vl-string-search "PC10" nom) "10")
    (T "10")))

(defun la:es-poste (nom)
  (or (wcmatch nom "_PC1#,PC1#,PM14")
      (wcmatch nom "A$C*")))

(defun la:es-combo (nom) (vl-string-search " + PC" nom))

(defun c:LOTEAP (/ f lin parts p rot circ ss n i e cnt id cajas275 trafos
                 redes lums etqs txt info nodo1 nodo2 e1 e2 lng best bd d
                 vals tr postes pts pn lref lcnt px py obj nb blks distv
                 sinlum lejos)
  (la:log "== LOTE AP v2: inicio ==")
  (mp:ensure-layers)
  ;; ---------- FASE A: borrar el AP anterior
  (setq ss (ssget "_X" '((0 . "INSERT")
    (2 . "MP_PUNTO_LUMINARIA*,MP_TRAMO_BTAP_*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n) (entdel (ssname ss i)) (setq i (1+ i)))
  (la:log (strcat "FASE A: " (itoa n) " elementos AP anteriores borrados"))
  ;; ---------- leer datos
  (setq lr:nodos nil lr:existentes nil lr:tramos-creados nil)
  (setq cajas275 nil trafos nil redes nil lums nil)
  (setq f (open (strcat lr:dir "data_AP_CRT.txt") "r"))
  (setq cnt 0)
  (while (setq lin (read-line f))
    (setq parts (lr:split lin "|"))
    (cond
      ((= (car parts) "CAJA274")
        (setq p (lr:parse-pt (caddr parts)))
        (setq cnt (1+ cnt))
        (la:caja "CAMARA_CS274" (list (car p) (cadr p) 0.0)
          (atof (nth 3 parts)) (strcat "A274-" (itoa cnt)) (cadr parts))
        (setq lr:nodos (cons (list p (strcat "A274-" (itoa cnt)) (entlast) "CAMARA_CS274") lr:nodos)))
      ((= (car parts) "CAJA275")
        (setq cajas275 (cons parts cajas275)))
      ((= (car parts) "TRAFO")
        (setq trafos (cons parts trafos)))
      ((= (car parts) "REDBT")
        (setq redes (cons parts redes)))
      ((= (car parts) "LUM")
        (setq lums (cons parts lums)))))
  (close f)
  (la:log (strcat "FASE B: " (itoa cnt) " cajas AP-274 creadas"))
  ;; CS-275
  (setq cnt 0)
  (foreach parts (reverse cajas275)
    (setq p (lr:parse-pt (caddr parts)))
    (setq cnt (1+ cnt))
    (la:caja "CAMARA_CS275" (list (car p) (cadr p) 0.0)
      (atof (nth 3 parts)) (strcat "A275-" (itoa cnt)) (cadr parts))
    (setq lr:nodos (cons (list p (strcat "A275-" (itoa cnt)) (entlast) "CAMARA_CS275") lr:nodos)))
  (la:log (strcat "FASE B: " (itoa cnt) " cajas CS-275 creadas"))
  ;; ---------- FASE C: transformadores pedestal
  (setq cnt 0)
  (foreach parts (reverse trafos)
    (setq p (lr:parse-pt (caddr parts)))
    (setq cnt (1+ cnt))
    (mp:insert-cant-point "TRANSFORMADOR_AP" (list (car p) (cadr p) 0.0)
      (list (cons "ID" (strcat "TP-" (itoa cnt)))
            (cons "CIRCUITO_AP" (cadr parts))))
    (setq lr:nodos (cons (list p (strcat "TP-" (itoa cnt)) (entlast) "TRANSFORMADOR_AP") lr:nodos)))
  (la:log (strcat "FASE C: " (itoa cnt) " transformadores pedestal"))
  ;; ---------- etiquetas d= de SERIE 6 (para ductos + longitud del plano)
  (setq etqs nil)
  (setq f (open (strcat lr:dir "data_SRC_SERIE6.txt") "r"))
  (while (setq lin (read-line f))
    (if (wcmatch lin "TXT|*,MLD|*")
      (progn
        (setq parts (lr:split lin "|"))
        (setq txt (nth 3 parts))
        (if (and txt (vl-string-search "d=" txt))
          (progn
            (setq p (car (lr:parse-pts (caddr parts))))
            (setq info (lr:parse-etq-mt txt))
            (if (and p info (car info))
              (setq etqs (cons (list (car p) (cadr p) (car info)
                (cadr info) (caddr info)) etqs))))))))
  (close f)
  (la:log (strcat "Etiquetas d= de SERIE 6: " (itoa (length etqs))))
  ;; ---------- FASE D: tramos caja a caja sobre la red real
  (setq tr 0 cnt 0)
  (foreach parts (reverse redes)
    (setq pts (lr:parse-pts (caddr parts)))
    (if (>= (length pts) 2)
      (progn
        (setq e1 (car (lr:chain-extremos pts))
              e2 (cadr (lr:chain-extremos pts)))
        (setq lng (lr:chain-len pts))
        (setq cnt (1+ cnt))
        (setq nodo1 (lr:nodo-mas-cercano e1 1.5))
        (setq nodo2 (lr:nodo-mas-cercano e2 1.5))
        (if (null nodo1) (setq nodo1 (list e1 (strcat "AP" (itoa cnt) "A") nil nil)))
        (if (null nodo2) (setq nodo2 (list e2 (strcat "AP" (itoa cnt) "B") nil nil)))
        ;; etiqueta d= mas cercana al medio que calce en longitud (+-6)
        (setq px (/ (+ (car e1) (car e2)) 2.0)
              py (/ (+ (cadr e1) (cadr e2)) 2.0))
        (setq best nil bd 30.0)
        (foreach info etqs
          (setq d (lr:d2 (list (car info) (cadr info)) (list px py)))
          (if (and (< d bd) (< (abs (- (caddr info) lng)) 6.0))
            (setq bd d best info)))
        (setq vals
          (list (cons "RED" "ELECTRICA-BT-AP") (cons "TIPO_RED" "AP")
                (cons "UBICACION" "ANDEN O ZONA VERDE")
                (cons "DUCTOS" (itoa (if (and best (nth 3 best)) (nth 3 best) 2)))
                (cons "DIAM_DUCTO" "3")
                (cons "MATERIAL_DUCTO" "PVC")
                (cons "CONDUCTOR" "3x4+4 THW")
                (cons "CIRCUITO_AP" (cadr parts))
                (cons "POZO_INI" (cadr nodo1))
                (cons "POZO_FIN" (cadr nodo2))
                (cons "HANDLE_EXTREMO_INI" (lr:handle-de (caddr nodo1)))
                (cons "HANDLE_EXTREMO_FIN" (lr:handle-de (caddr nodo2)))))
        (mp:insert-cant-tramo "TRAMO_E_BT_AP"
          (list (car (car nodo1)) (cadr (car nodo1)) 0.0)
          (list (car (car nodo2)) (cadr (car nodo2)) 0.0)
          vals)
        (setq e (entlast))
        ;; longitud del plano cuando la etiqueta valida
        (if best
          (progn
            (mp:setatt-one e "LONGITUD" (rtos (caddr best) 2 2))
            (mp:setatt-one e "LONG_VIS" (strcat "L=" (rtos (caddr best) 2 2)))))
        (setq tr (1+ tr)))))
  (la:log (strcat "FASE D: " (itoa tr) " tramos AP caja a caja"))
  ;; ---------- FASE E: postes con sus luminarias
  ;; postes = simbolos PC/PM/A$C + combos "RALED xx + PCxx"
  (setq postes nil)
  (foreach parts lums
    (setq nb (caddr parts))
    (if (or (la:es-poste nb) (la:es-combo nb))
      (progn
        (setq p (lr:parse-pt (nth 3 parts)))
        ;; (x y altura circuito lum-cnt lum-ref)
        (setq postes (cons (list (car p) (cadr p) (la:altura-de nb)
          (cadr parts)
          (if (la:es-combo nb) 1 0)
          (if (la:es-combo nb)
            (substr nb 1 (vl-string-search " + PC" nb)) ""))
          postes)))))
  ;; luminarias puras -> al poste mas cercano (<= 7 m)
  (setq sinlum 0 lejos 0)
  (foreach parts lums
    (setq nb (caddr parts))
    (if (and (not (la:es-poste nb)) (not (la:es-combo nb)))
      (progn
        (setq p (lr:parse-pt (nth 3 parts)))
        (setq best nil bd 7.0)
        (foreach pn postes
          (setq d (lr:d2 p (list (car pn) (cadr pn))))
          (if (< d bd) (setq bd d best pn)))
        (if best
          (setq postes
            (subst
              (list (car best) (cadr best) (caddr best) (nth 3 best)
                (1+ (nth 4 best))
                (if (= (nth 5 best) "") nb (nth 5 best)))
              best postes))
          (setq lejos (1+ lejos))))))
  (setq cnt 0)
  (foreach pn postes
    (setq cnt (1+ cnt))
    (mp:insert-cant-point "POSTE_ELEC"
      (list (car pn) (cadr pn) 0.0)
      (list (cons "ID" (strcat "P-" (itoa cnt)))
            (cons "TIPO_RED" "AP")
            (cons "ALTURA_M" (caddr pn))
            (cons "CIRCUITO_AP" (nth 3 pn))
            (cons "LUMINARIAS" (itoa (max 1 (nth 4 pn))))
            (cons "TIPO_LUMINARIA" (nth 5 pn))))
    (if (= (nth 4 pn) 0) (setq sinlum (1+ sinlum))))
  (la:log (strcat "FASE E: " (itoa cnt) " postes creados | sin luminaria asignada: "
    (itoa sinlum) " (quedan con 1 por defecto) | luminarias sin poste cerca: "
    (itoa lejos)))
  ;; ---------- FASE F: reparar defs BTAP reutilizadas + etiquetas
  (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
  (setq n 0)
  (vlax-for e blks
    (setq nb (vla-get-Name e))
    (if (wcmatch nb "MP_TRAMO_BTAP_*")
      (progn
        (setq distv (atof (vl-string-translate "_" "."
          (substr nb (+ 6 (vl-string-search "BTAP_" nb))))))
        (setq best nil)
        (vlax-for obj e
          (cond
            ((= (vla-get-ObjectName obj) "AcDbCircle")
              (vl-catch-all-apply 'vla-Delete (list obj)))
            ((= (vla-get-ObjectName obj) "AcDbPolyline")
              (vl-catch-all-apply 'vla-put-ConstantWidth (list obj 0.20))
              (setq lin (entget (vlax-vla-object->ename obj)))
              (setq lin (subst (cons 10 (list 0.0 0.0)) (assoc 10 lin) lin))
              (entmod
                (reverse
                  (subst (cons 10 (list distv 0.0))
                    (assoc 10 (reverse lin)) (reverse lin)))))
            ((= (vla-get-ObjectName obj) "AcDbAttributeDefinition")
              (if (> (vla-get-Height obj) 0.9) (vla-put-Height obj 0.9))
              (if (= (strcase (vla-get-TagString obj)) "LONG_VIS")
                (setq best T)))))
        (if (null best)
          (mp:center-visible-att
            (mp:vla-add-att e "LONG_VIS" "Longitud visible" ""
              (list (/ distv 2.0) -1.25 0.0) 0.9 nil "PPTO-ELECTRICA-BT-AP" 2)
            (list (/ distv 2.0) -1.25 0.0) 0.9))
        (vl-cmdf "_.ATTSYNC" "_N" nb)
        (setq n (1+ n)))))
  (la:log (strcat "FASE F: " (itoa n) " defs BTAP normalizadas"))
  ;; etiquetas de instancia (las que ATTSYNC dejo con default)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_BTAP_*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (setq txt "")
    (foreach p (vlax-invoke obj 'GetAttributes)
      (if (= (strcase (vla-get-TagString p)) "LONGITUD")
        (setq txt (vla-get-TextString p))))
    (foreach p (vlax-invoke obj 'GetAttributes)
      (cond
        ((= (strcase (vla-get-TagString p)) "LONG_VIS")
          (if (= (vla-get-TextString p) "")
            (vla-put-TextString p (strcat "L=" txt))))))
    (setq i (1+ i)))
  ;; ---------- resumen
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_CAMARA_CS274"))))
  (la:log (strcat "VERIF cajas AP-274: " (itoa (if ss (sslength ss) 0))))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_BTAP_*"))))
  (la:log (strcat "VERIF tramos BTAP: " (itoa (if ss (sslength ss) 0))))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_POSTE*"))))
  (la:log (strcat "VERIF postes: " (itoa (if ss (sslength ss) 0))))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (la:log "== LOTE AP v2: TERMINADO =="))
(c:LOTEAP)
