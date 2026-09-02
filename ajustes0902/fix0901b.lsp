;;; fix0901b.lsp (2026-09-01 noche, 2a ronda) - intervenciones al master:
;;; BORRAEJEC  - borra los elementos de las capas *-EJEC (ya ejecutados;
;;;              el usuario pidio quitarlas; el ppto queda solo-pendiente)
;;;              y purga esas capas.
;;; MOVERACC   - accesorios ACU a la capa PPTO-ACUEDUCTO (una capa por
;;;              red) y purga PPTO-ACCESORIOS-ACUEDUCTO.
;;; AUDITACC   - centro del simbolo de cada tipo de accesorio vs (0,0).
;;; CENTRAACC  - re-centra defs de accesorio corridos (geometria, no
;;;              attdefs) para que el simbolo caiga en el punto real.
;;; REWIPE     - reaplica wipeout C11 + draworder si la sesion del
;;;              usuario piso el guardado de anoche (con guarda).
;;; REFIXVIA   - reaplica el refresco de atributos de sobreancho.
;;; Requiere plugin cargado.

(defun fb:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/ronda2.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun c:BORRAEJEC (/ doc lay nombres nm ss i n tot)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  ;; recolectar nombres de capas *-EJEC
  (setq nombres nil)
  (vlax-for lay (vla-get-Layers doc)
    (if (wcmatch (strcase (vla-get-Name lay)) "*-EJEC")
      (setq nombres (cons (vla-get-Name lay) nombres))))
  (fb:log (strcat "BORRAEJEC capas: " (itoa (length nombres))))
  (setq tot 0)
  (foreach nm nombres
    ;; capa visible/descongelada para poder seleccionar y borrar
    (setq lay (vla-Item (vla-get-Layers doc) nm))
    (vl-catch-all-apply 'vla-put-Freeze (list lay :vlax-false))
    (vl-catch-all-apply 'vla-put-LayerOn (list lay :vlax-true))
    (vl-catch-all-apply 'vla-put-Lock (list lay :vlax-false))
    (setq ss (ssget "_X" (list (cons 8 nm))) n 0 i 0)
    (if ss
      (while (< i (sslength ss))
        (if (entget (ssname ss i))
          (progn (entdel (ssname ss i)) (setq n (1+ n))))
        (setq i (1+ i))))
    (setq tot (+ tot n))
    ;; purgar la capa (falla silenciosa si algo la referencia aun)
    (setq lay (vl-catch-all-apply
      '(lambda () (vla-Delete (vla-Item (vla-get-Layers doc) nm)))))
    (fb:log (strcat "  " nm ": " (itoa n) " entidades borradas | capa "
      (if (vl-catch-all-error-p lay) "NO purgada" "purgada"))))
  (fb:log (strcat "BORRAEJEC total: " (itoa tot) " entidades"))
  (princ))

(defun c:MOVERACC (/ doc ss i en n res)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq ss (ssget "_X" '((8 . "PPTO-ACCESORIOS-ACUEDUCTO"))) n 0 i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (vl-catch-all-apply 'vla-put-Layer
        (list (vlax-ename->vla-object en) "PPTO-ACUEDUCTO"))
      (setq n (1+ n) i (1+ i))))
  (setq res (vl-catch-all-apply
    '(lambda () (vla-Delete
      (vla-Item (vla-get-Layers doc) "PPTO-ACCESORIOS-ACUEDUCTO")))))
  (fb:log (strcat "MOVERACC: " (itoa n)
    " elementos a PPTO-ACUEDUCTO | capa vieja "
    (if (vl-catch-all-error-p res) "NO purgada" "purgada")))
  (princ))

(defun fb:def-center (blk / minx miny maxx maxy e res p1 p2 ll ur)
  (vlax-for e blk
    (if (not (member (vla-get-ObjectName e)
          '("AcDbAttributeDefinition")))
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

(defun c:AUDITACC (/ doc blks blk bname c ss n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (vlax-for blk blks
    (setq bname (vla-get-Name blk))
    (if (wcmatch (strcase bname) "MP_PUNTO_ACC_ACU*")
      (progn
        (setq c (fb:def-center blk))
        (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 bname))))
        (setq n (if ss (sslength ss) 0))
        (if c
          (fb:log (strcat "AUDITACC " bname " | centro ("
            (rtos (nth 0 c) 2 3) ", " (rtos (nth 1 c) 2 3)
            ") | tam " (rtos (nth 2 c) 2 2) "x" (rtos (nth 3 c) 2 2)
            " | instancias " (itoa n)))
          (fb:log (strcat "AUDITACC " bname " sin bbox | instancias "
            (itoa n)))))))
  (princ))

(defun c:CENTRAACC (/ doc blks blk bname c ents e n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq n 0)
  (vlax-for blk blks
    (setq bname (vla-get-Name blk))
    (if (wcmatch (strcase bname) "MP_PUNTO_ACC_ACU*")
      (progn
        (setq c (fb:def-center blk))
        (if (and c (or (> (abs (nth 0 c)) 0.25) (> (abs (nth 1 c)) 0.25)))
          (progn
            ;; recolectar -> mutar (regla de oro): mover geometria, no attdefs
            (setq ents nil)
            (vlax-for e blk
              (if (not (member (vla-get-ObjectName e)
                    '("AcDbAttributeDefinition")))
                (setq ents (cons e ents))))
            (foreach e ents
              (vl-catch-all-apply 'vla-Move
                (list e
                  (vlax-3d-point (list (nth 0 c) (nth 1 c) 0.0))
                  (vlax-3d-point '(0.0 0.0 0.0)))))
            (setq n (1+ n))
            (fb:log (strcat "CENTRAACC " bname " corrido ("
              (rtos (nth 0 c) 2 3) ", " (rtos (nth 1 c) 2 3)
              ") -> centrado")))))))
  (fb:log (strcat "CENTRAACC: " (itoa n) " definiciones re-centradas"))
  (vla-Regen doc 1)
  (princ))

(defun c:REWIPE (/ doc blks blk nw e minx miny maxx maxy c m cx cy hw hh
                 pl went res copied table ss)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (if (not (tblsearch "BLOCK" "MP_PUNTO_ACC_ACU_C11"))
    (fb:log "REWIPE: no existe C11")
    (progn
      (setq blk (vla-Item blks "MP_PUNTO_ACC_ACU_C11"))
      (setq nw 0)
      (vlax-for e blk
        (if (= "AcDbWipeout" (vla-get-ObjectName e)) (setq nw (1+ nw))))
      (if (> nw 0)
        (fb:log "REWIPE: C11 ya tiene wipeout (guardado de anoche intacto)")
        (progn
          (setq c (fb:def-center blk))
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
                  (fb:log "REWIPE: wipeout C11 re-aplicado"))
                (fb:log "REWIPE: FALLO copia")))
            (progn
              (fb:log "REWIPE: FALLO comando WIPEOUT")
              (if (and pl (entget pl)) (entdel pl))))))
      ;; accesorios al frente siempre (idempotente)
      (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))))
      (if ss
        (progn
          (vl-catch-all-apply 'vl-cmdf (list "_.DRAWORDER" ss "" "_Front"))
          (fb:log (strcat "REWIPE: draworder frente "
            (itoa (sslength ss)) " accs"))))
      (vla-Regen doc 1)))
  (princ))

(defun c:REFIXVIA (/ ss i be d obj nombre area span nuevo n)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons -3 (list (list "URB_VIA"))))) i 0 n 0)
  (if ss
    (while (< i (sslength ss))
      (setq be (ssname ss i)
            d (urb:get-xdata-strings be "URB_VIA")
            obj (vlax-ename->vla-object be)
            nombre (urb:safe-string (nth 1 d) "VIA")
            area (atof (urb:safe-string (nth 17 d) "0"))
            span (atof (urb:safe-string (nth 18 d) "0"))
            nuevo (+ area (* span
              (+ (atof (urb:safe-string (nth 14 d) "0"))
                 (atof (urb:safe-string (nth 15 d) "0"))))))
      (urb:set-block-attribute obj "VIA_AREA_SOBREANCHO_M2" (rtos nuevo 2 2))
      (urb:set-block-attribute obj "VIA_SOBREANCHO_M2" (rtos (- nuevo area) 2 2))
      (fb:log (strcat "REFIXVIA " nombre " -> " (rtos nuevo 2 2)))
      (setq n (1+ n) i (1+ i))))
  (fb:log (strcat "REFIXVIA: " (itoa n) " vias"))
  (princ))
(princ "\nfix0901b listo")(princ)
