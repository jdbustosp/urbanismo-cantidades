;;; fix0907.lsp - ronda DWG 2026-09-07 (correr sobre el MASTER VIGENTE
;;; de SharePoint con el motor 4.72.0 cargado):
;;; WIPETODOS  - wipeout al fondo de los 13 defs de accesorio ACU (el
;;;              piloto C11 gusto; el usuario pidio ver la red limpia)
;;;              + WIPEOUTFRAME 0 + accesorios al frente.
;;; RELABELACC - ETIQUETA de accesorios = SOLO el numero (motor 4.72) +
;;;              re-centrado; usa la logica oficial mp:label-point.
;;; CLEANACCATTS - borra de los 13 defs los ATTDEF que salieron del
;;;              esquema (LOTE, SUPERFICIE_TN, ESTADO_COTA_TN,
;;;              ORIGEN_CREACION) + ATTSYNC (valores de los tags
;;;              restantes se conservan; los borrados viven en XDATA).
;;; DIAGCONEX3 - censo de conexion accesorio<->tramo ACU (seguimiento).
(defun f7:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/pdf0907/ronda4.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun f7:def-center-size (blk / minx miny maxx maxy e res p1 p2 ll ur)
  (vlax-for e blk
    (if (not (member (vla-get-ObjectName e)
          '("AcDbAttributeDefinition" "AcDbWipeout")))
      (progn
        (setq res (vl-catch-all-apply 'vla-GetBoundingBox (list e 'll 'ur)))
        (if (not (vl-catch-all-error-p res))
          (progn
            (setq p1 (vlax-safearray->list ll)
                  p2 (vlax-safearray->list ur))
            (if (or (null minx) (< (car p1) minx)) (setq minx (car p1)))
            (if (or (null miny) (< (cadr p1) miny)) (setq miny (cadr p1)))
            (if (or (null maxx) (> (car p2) maxx)) (setq maxx (car p2)))
            (if (or (null maxy) (> (cadr p2) maxy)) (setq maxy (cadr p2))))))))
  (if (and minx maxx)
    (list (* 0.5 (+ minx maxx)) (* 0.5 (+ miny maxy))
          (- maxx minx) (- maxy miny))
    nil))

(defun f7:wipe-def (bname / doc blk e nw c m cx cy hw hh pl went res copied table)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (not (tblsearch "BLOCK" bname))
    (f7:log (strcat "WIPETODOS: no existe " bname))
    (progn
      (setq blk (vla-Item (vla-get-Blocks doc) bname))
      (setq nw 0)
      (vlax-for e blk
        (if (= "AcDbWipeout" (vla-get-ObjectName e)) (setq nw (1+ nw))))
      (if (> nw 0)
        (f7:log (strcat "WIPETODOS " bname ": ya tiene wipeout"))
        (progn
          (setq c (f7:def-center-size blk))
          (if (null c)
            (f7:log (strcat "WIPETODOS " bname ": sin bbox"))
            (progn
              (setq m 0.10
                    cx (nth 0 c) cy (nth 1 c)
                    hw (+ m (* 0.5 (nth 2 c)))
                    hh (+ m (* 0.5 (nth 3 c))))
              (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
                '(100 . "AcDbPolyline") '(90 . 4) '(70 . 1)
                (cons 10 (list (- cx hw) (- cy hh)))
                (cons 10 (list (+ cx hw) (- cy hh)))
                (cons 10 (list (+ cx hw) (+ cy hh)))
                (cons 10 (list (- cx hw) (+ cy hh)))))
              (setq pl (entlast))
              (setq res (vl-catch-all-apply 'vl-cmdf
                (list "_.WIPEOUT" "_P" pl "_Y")))
              (setq went (entlast))
              (if (and went (= (cdr (assoc 0 (entget went))) "WIPEOUT"))
                (progn
                  (setq res (vl-catch-all-apply 'vla-CopyObjects
                    (list doc (urb:object-array-variant
                      (list (vlax-ename->vla-object went))) blk)))
                  (entdel went)
                  (setq copied nil)
                  (vlax-for e blk
                    (if (= "AcDbWipeout" (vla-get-ObjectName e)) (setq copied e)))
                  (if copied
                    (progn
                      (setq table (urb:sortents-table blk))
                      (vl-catch-all-apply 'vla-MoveToBottom
                        (list table (urb:object-array-variant (list copied))))
                      (f7:log (strcat "WIPETODOS " bname ": wipeout OK ("
                        (rtos (* 2 hw) 2 2) "x" (rtos (* 2 hh) 2 2) ")")))
                    (f7:log (strcat "WIPETODOS " bname ": copia perdida"))))
                (progn
                  (f7:log (strcat "WIPETODOS " bname ": FALLO comando"))
                  (if (and pl (entget pl)) (entdel pl))))))))))
  (princ))

(defun c:WIPETODOS (/ lst ss res)
  (setvar "WIPEOUTFRAME" 0)
  (setq lst '("MP_PUNTO_ACC_ACU_TEE" "MP_PUNTO_ACC_ACU_VCP"
    "MP_PUNTO_ACC_ACU_VPH" "MP_PUNTO_ACC_ACU_VEN" "MP_PUNTO_ACC_ACU_VAL"
    "MP_PUNTO_ACC_ACU_HID" "MP_PUNTO_ACC_ACU_TAP" "MP_PUNTO_ACC_ACU_RDC"
    "MP_PUNTO_ACC_ACU_C11" "MP_PUNTO_ACC_ACU_UNI" "MP_PUNTO_ACC_ACU_C45"
    "MP_PUNTO_ACC_ACU_C22" "MP_PUNTO_ACC_ACU_C90"))
  (foreach bname lst (f7:wipe-def bname))
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU*"))))
  (if ss
    (progn
      (setq res (vl-catch-all-apply 'vl-cmdf
        (list "_.DRAWORDER" ss "" "_Front")))
      (f7:log (strcat "WIPETODOS: draworder frente "
        (itoa (sslength ss)) " accesorios"))))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (f7:log "FIN-WIPETODOS")
  (princ))

(defun c:RELABELACC (/ ss i en atts n)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_PUNTO_ACC_ACU*"))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            atts (mp:att-alist en))
      (mp:setatt-one en "ETIQUETA"
        (mp:label-point "ACCESORIO_ACUEDUCTO" atts))
      (mp:level-etiqueta-atts en)
      (setq n (1+ n) i (1+ i))))
  (f7:log (strcat "RELABELACC: " (itoa n)
    " accesorios con etiqueta SOLO numero"))
  (princ))

(defun c:CLEANACCATTS (/ doc blks bname blk e victims n tot res lst)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc) tot 0)
  (setq lst '("LOTE" "SUPERFICIE_TN" "ESTADO_COTA_TN" "ORIGEN_CREACION"))
  (vlax-for blk blks
    (setq bname (vla-get-Name blk))
    (if (wcmatch (strcase bname) "MP_PUNTO_ACC_ACU*")
      (progn
        (setq victims nil)
        (vlax-for e blk
          (if (and (= "AcDbAttributeDefinition" (vla-get-ObjectName e))
                   (member (strcase (vla-get-TagString e)) lst))
            (setq victims (cons e victims))))
        (setq n 0)
        (foreach e victims
          (if (not (vl-catch-all-error-p
                (vl-catch-all-apply 'vla-Delete (list e))))
            (setq n (1+ n))))
        (if (> n 0)
          (progn
            (setq res (vl-catch-all-apply 'vl-cmdf
              (list "_.ATTSYNC" "_N" bname)))
            (f7:log (strcat "CLEANACCATTS " bname ": " (itoa n)
              " attdefs fuera"
              (if (vl-catch-all-error-p res) " ATTSYNC-FALLO" "")))
            (setq tot (+ tot n)))))))
  (f7:log (strcat "CLEANACCATTS total: " (itoa tot) " attdefs eliminados"))
  (princ))

(defun f7:tramo-ends (en / ed p rot atts l)
  (setq ed (entget en))
  (setq p (cdr (assoc 10 ed)) rot (cdr (assoc 50 ed)))
  (setq atts (mp:att-alist en))
  (setq l (distof (mp:getval "LONGITUD_2D" atts
            (mp:getval "LONGITUD" atts "0"))))
  (if (or (null l) (<= l 0.0)) (setq l 0.0))
  (list (car p) (cadr p)
        (+ (car p) (* l (cos rot))) (+ (cadr p) (* l (sin rot)))))

(defun c:DIAGCONEX3 (/ ss i en atts ends item pc best d n-ok n-cerca n-lejos)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*")))
        i 0 ends nil)
  (if ss
    (while (< i (sslength ss))
      (setq item (f7:tramo-ends (ssname ss i)))
      (setq ends (cons (list (nth 0 item) (nth 1 item)) ends))
      (setq ends (cons (list (nth 2 item) (nth 3 item)) ends))
      (setq i (1+ i))))
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*")))
        i 0 n-ok 0 n-cerca 0 n-lejos 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i)
            pc (cdr (assoc 10 (entget en)))
            best 1e9)
      (foreach item ends
        (setq d (distance (list (car pc) (cadr pc)) item))
        (if (< d best) (setq best d)))
      (cond
        ((<= best 0.05) (setq n-ok (1+ n-ok)))
        ((<= best 0.50) (setq n-cerca (1+ n-cerca)))
        (T (setq n-lejos (1+ n-lejos))))
      (setq i (1+ i))))
  (f7:log (strcat "DIAGCONEX3: conectados " (itoa n-ok)
    " | cerca " (itoa n-cerca) " | sin tramo " (itoa n-lejos)))
  (princ))
(princ "\nfix0907 listo")(princ)
