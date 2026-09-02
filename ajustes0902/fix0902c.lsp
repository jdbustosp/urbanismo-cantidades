;;; fix0902c.lsp (2026-09-02, ronda 3) - intervenciones al master:
;;; FIXFRAME    - WIPEOUTFRAME 0 (los accesorios se veian "encerrados"
;;;               por el marco del wipeout del piloto).
;;; POZOREAL    - pozos/sumideros a tamano real en los defs existentes
;;;               (pozo r=0.60 D1.20 real, sumidero r=0.35) + etiquetas
;;;               proporcionales afuera + ATTSYNC.
;;; RETRIMHIDRO - reconstruye tramos SAN/PLU con recorte visual viejo
;;;               (gap 2.0) para que lleguen al borde del pozo real
;;;               (gap 0.60 lo aplica el motor 4.68 al reconstruir).
;;; RECENTRA    - reposiciona las etiquetas de TODOS los tramos a su
;;;               punto de diseno (reporte "cotas no centradas").
;;; PREFRONT    - prefabricados existentes al frente (bordillo tapado
;;;               por el anden).
;;; AUDITMOV2   - auditoria del MT de andenes/zonas verdes/rampas del
;;;               usuario (verificacion pedida).
;;; DIAGCONEX2  - censo de conexion accesorio<->tramo ACU (investigacion
;;;               "sigue mal").
;;; Requiere plugin 4.68.0 cargado.

(defun fc:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/ronda3.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun c:FIXFRAME ()
  (setvar "WIPEOUTFRAME" 0)
  (fc:log "FIXFRAME: WIPEOUTFRAME=0 (marcos de wipeout ocultos)")
  (princ))

(defun fc:fix-pozo-def (bname r th ypos / doc blk e n res)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (not (tblsearch "BLOCK" bname))
    (fc:log (strcat "POZOREAL: no existe " bname))
    (progn
      (setq blk (vla-Item (vla-get-Blocks doc) bname) n 0)
      (vlax-for e blk
        (cond
          ((= "AcDbCircle" (vla-get-ObjectName e))
            (vla-put-Radius e r) (setq n (1+ n)))
          ((and (= "AcDbAttributeDefinition" (vla-get-ObjectName e))
                (= "ETIQUETA" (strcase (vla-get-TagString e))))
            (vla-put-Height e th)
            (vl-catch-all-apply 'vlax-put
              (list e 'InsertionPoint (list 0.0 ypos 0.0)))
            (vl-catch-all-apply 'vlax-put
              (list e 'TextAlignmentPoint (list 0.0 ypos 0.0)))
            (setq n (1+ n)))))
      (setq res (vl-catch-all-apply 'vl-cmdf
        (list "_.ATTSYNC" "_N" bname)))
      (fc:log (strcat "POZOREAL " bname ": " (itoa n)
        " entidades ajustadas (r=" (rtos r 2 2) ")"
        (if (vl-catch-all-error-p res) " ATTSYNC-FALLO" ""))))))

(defun c:POZOREAL (/ doc blk e n res)
  (fc:fix-pozo-def "MP_PUNTO_POZO_SAN" 0.60 0.60 1.05)
  (fc:fix-pozo-def "MP_PUNTO_POZO_PLU" 0.60 0.60 1.05)
  ;; sumidero: rombo r=0.35 + etiqueta pegada
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (tblsearch "BLOCK" "MP_PUNTO_SUMIDERO")
    (progn
      (setq blk (vla-Item (vla-get-Blocks doc) "MP_PUNTO_SUMIDERO") n 0)
      (vlax-for e blk
        (cond
          ((= "AcDbPolyline" (vla-get-ObjectName e))
            (vla-put-Coordinates e
              (mp:var-dbls '(-0.35 0.0 0.0 0.35 0.35 0.0 0.0 -0.35)))
            (vla-put-ConstantWidth e 0.12)
            (setq n (1+ n)))
          ((and (= "AcDbAttributeDefinition" (vla-get-ObjectName e))
                (= "ETIQUETA" (strcase (vla-get-TagString e))))
            (vla-put-Height e 0.60)
            (vl-catch-all-apply 'vlax-put
              (list e 'InsertionPoint '(0.55 0.55 0.0)))
            (setq n (1+ n)))))
      (setq res (vl-catch-all-apply 'vl-cmdf
        (list "_.ATTSYNC" "_N" "MP_PUNTO_SUMIDERO")))
      (fc:log (strcat "POZOREAL MP_PUNTO_SUMIDERO: " (itoa n)
        " entidades (r=0.35)"
        (if (vl-catch-all-error-p res) " ATTSYNC-FALLO" ""))))
    (fc:log "POZOREAL: no existe MP_PUNTO_SUMIDERO"))
  (princ))

;; longitud visible codificada en el nombre del bloque MP_TRAMO_XXX_12_35
(defun fc:span-from-name (bname / p s)
  (setq p (vl-string-search "_" bname
            (+ 9 (vl-string-search "MP_TRAMO_" bname))))
  (if p
    (progn
      (setq s (substr bname (+ 2 p)))
      (setq s (vl-string-translate "_M" ".-" s))
      (distof s))
    nil))

(defun c:RETRIMHIDRO (/ ss i en obj bname atts base l ed ip rot span gap
                       dir p1 p2 lst en2 n-fix n-skip)
  (setq lst nil)
  (setq ss (ssget "_X" (list (cons 0 "INSERT")
             (cons 2 "MP_TRAMO_SAN_*,MP_TRAMO_PLU_*"))) i 0)
  (if ss (while (< i (sslength ss))
    (setq lst (cons (ssname ss i) lst)) (setq i (1+ i))))
  (fc:log (strcat "RETRIMHIDRO: " (itoa (length lst)) " tramos SAN/PLU"))
  (setq n-fix 0 n-skip 0)
  (foreach en lst
    (if (entget en)
      (progn
        (setq obj (vlax-ename->vla-object en)
              bname (vla-get-EffectiveName obj)
              atts (mp:att-alist en)
              ed (entget en)
              ip (cdr (assoc 10 ed))
              rot (cdr (assoc 50 ed))
              l (distof (mp:getval "LONGITUD_2D" atts
                  (mp:getval "LONGITUD" atts "0")))
              span (fc:span-from-name bname))
        (setq base
          (if (vl-string-search "_SAN_" bname)
            "TRAMO_ARESIDUAL" "TRAMO_ALLUVIAS"))
        (if (and l span (> l 0.0) (> (setq gap (/ (- l span) 2.0)) 0.30))
          (progn
            ;; extremos reales = insercion corrida gap hacia atras
            (setq dir (list (cos rot) (sin rot)))
            (setq p1 (list (- (car ip) (* gap (car dir)))
                           (- (cadr ip) (* gap (cadr dir)))))
            (setq p2 (list (+ (car p1) (* l (car dir)))
                           (+ (cadr p1) (* l (cadr dir)))))
            (setq atts (vl-remove-if
              (quote (lambda (a) (member (car a)
                (list "LONGITUD" "LONGITUD_2D" "LONGITUD_3D" "ETIQUETA"
                      "PENDIENTE_VIS"))))
              atts))
            (setq en2 (mp:insert-cant-tramo base p1 p2 atts))
            (if en2
              (progn (entdel en) (setq n-fix (1+ n-fix)))
              (setq n-skip (1+ n-skip))))
          (setq n-skip (1+ n-skip))))))
  (fc:log (strcat "RETRIMHIDRO: " (itoa n-fix) " reconstruidos (borde real) | "
    (itoa n-skip) " sin recorte viejo (intactos)"))
  (princ))

(defun c:RECENTRA (/ ss i en n res)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_*"))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (if (entget en)
        (progn
          (setq res (vl-catch-all-apply 'mp:recenter-tramo-attribs (list en)))
          (if (and res (not (vl-catch-all-error-p res)))
            (setq n (1+ n)))))
      (setq i (1+ i))))
  (fc:log (strcat "RECENTRA: " (itoa n) " tramos con etiquetas re-centradas"))
  (princ))

(defun c:PREFRONT (/ ss res)
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
  (if ss
    (progn
      (setq res (vl-catch-all-apply 'vl-cmdf
        (list "_.DRAWORDER" ss "" "_Front")))
      (fc:log (strcat "PREFRONT: " (itoa (sslength ss))
        " prefabricados al frente"
        (if (vl-catch-all-error-p res) " (FALLO)" ""))))
    (fc:log "PREFRONT: sin prefabricados"))
  (princ))

(defun c:AUDITMOV2 (/ ss i be atts d area corte relleno prof mov)
  ;; andenes
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_ANDEN_BLOCK")))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            atts (urb:block-attribute-values (vlax-ename->vla-object be))
            area (atof (urb:safe-string (cdr (assoc "AREA_M2" atts)) "0"))
            corte (atof (urb:safe-string (cdr (assoc "ANDEN_CORTE_M3" atts)) "0"))
            relleno (atof (urb:safe-string (cdr (assoc "ANDEN_RELLENO_M3" atts)) "0")))
      (fc:log (strcat "AUDITMOV anden " (cdr (assoc 5 (entget be)))
        " | area " (rtos area 2 1)
        " | corte " (rtos corte 2 2) " relleno " (rtos relleno 2 2)
        (if (> area 0.01)
          (strcat " | prof.media " (rtos (/ corte area) 2 3) " m") "")))
      (setq i (1+ i))))
  ;; zonas verdes
  (setq ss (ssget "_X" '((-3 ("URB_GREEN_BLOCK")))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            atts (urb:block-attribute-values (vlax-ename->vla-object be))
            area (atof (urb:safe-string (cdr (assoc "AREA_M2" atts)) "0"))
            corte (atof (urb:safe-string (cdr (assoc "CORTE_M3" atts)) "0"))
            relleno (atof (urb:safe-string (cdr (assoc "RELLENO_M3" atts)) "0")))
      (fc:log (strcat "AUDITMOV zverde " (cdr (assoc 5 (entget be)))
        " | area " (rtos area 2 1)
        " | corte " (rtos corte 2 2) " relleno " (rtos relleno 2 2)
        (if (> area 0.01)
          (strcat " | balance " (rtos (/ (- corte relleno) area) 2 3) " m") "")))
      (setq i (1+ i))))
  ;; rampas
  (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_RAMPA_BLOCK")))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            atts (urb:block-attribute-values (vlax-ename->vla-object be))
            area (atof (urb:safe-string (cdr (assoc "AREA_M2" atts)) "0"))
            mov (urb:get-xdata-strings be "URB_RAMPA_MOV"))
      (fc:log (strcat "AUDITMOV rampa " (cdr (assoc 5 (entget be)))
        " | area " (rtos area 2 1)
        (if mov
          (strcat " | corte " (urb:safe-string (nth 0 mov) "?")
            " relleno " (urb:safe-string (nth 1 mov) "?"))
          " | SIN corte/relleno calculado")))
      (setq i (1+ i))))
  (fc:log "FIN-AUDITMOV2")
  (princ))

(defun fc:tramo-ends (en / ed p rot atts l)
  (setq ed (entget en))
  (setq p (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
  (setq atts (mp:att-alist en))
  (setq l (distof (mp:getval "LONGITUD_2D" atts
            (mp:getval "LONGITUD" atts "0"))))
  (if (or (null l) (<= l 0.0)) (setq l 0.0))
  (list (car p) (cadr p)
        (+ (car p) (* l (cos rot))) (+ (cadr p) (* l (sin rot)))))

(defun c:DIAGCONEX2 (/ ss i en atts accs tramos ends item pc best d
                      n-ok n-cerca n-lejos peores)
  ;; extremos de todos los tramos ACU
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*")))
        i 0 ends nil)
  (if ss
    (while (< i (sslength ss))
      (setq item (fc:tramo-ends (ssname ss i)))
      (setq ends (cons (list (nth 0 item) (nth 1 item)) ends))
      (setq ends (cons (list (nth 2 item) (nth 3 item)) ends))
      (setq i (1+ i))))
  (fc:log (strcat "DIAGCONEX2: " (itoa (/ (length ends) 2)) " tramos ACU"))
  ;; accesorios
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*")))
        i 0 n-ok 0 n-cerca 0 n-lejos 0 peores nil)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en)
            pc (cdr (assoc 10 (entget en)))
            best 1e9)
      (foreach item ends
        (setq d (distance (list (car pc) (cadr pc)) item))
        (if (< d best) (setq best d)))
      (cond
        ((<= best 0.05) (setq n-ok (1+ n-ok)))
        ((<= best 0.50) (setq n-cerca (1+ n-cerca)))
        (T (setq n-lejos (1+ n-lejos))
           (setq peores (cons (list best
             (mp:getval "ID" atts (mp:getval "ETIQUETA" atts "?"))
             pc) peores))))
      (setq i (1+ i))))
  (fc:log (strcat "DIAGCONEX2: conectados(<=5cm) " (itoa n-ok)
    " | cerca(<=50cm) " (itoa n-cerca)
    " | SIN tramo cerca(>50cm) " (itoa n-lejos)))
  (setq peores (vl-sort peores (quote (lambda (a b) (> (car a) (car b))))))
  (setq i 0)
  (foreach item peores
    (if (< i 15)
      (fc:log (strcat "  LEJOS " (cadr item) " d="
        (rtos (car item) 2 2) " en ("
        (rtos (car (caddr item)) 2 1) ", "
        (rtos (cadr (caddr item)) 2 1) ")")))
    (setq i (1+ i)))
  (fc:log "FIN-DIAGCONEX2")
  (princ))
(princ "\nfix0902c listo")(princ)
