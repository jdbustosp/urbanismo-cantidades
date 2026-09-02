;;; wipeacc2.lsp (2026-09-02) - v2 forense del piloto wipeout: log por
;;; linea (abrir/cerrar en cada escritura, un crash no pierde la cola) y
;;; cada paso en vl-catch-all. Ver wipeacc.lsp para el contexto.
(defun w2:log (msg / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/ajustes0902/wipe2.txt" "a"))
  (if f (progn (write-line msg f) (close f)))
  (princ (strcat "\n" msg)) (princ))

(defun c:WIPEACC2 (/ doc blks blkname blk minx miny maxx maxy e res p1 p2
                    m cx cy hw hh pl went wobj copied table ss ll ur)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq blks (vla-get-Blocks doc))
  (setq blkname "MP_PUNTO_ACC_ACU_C11")
  (w2:log "paso 1: inicio")
  (if (not (tblsearch "BLOCK" blkname))
    (w2:log (strcat "NO EXISTE " blkname))
    (progn
      (setq blk (vla-Item blks blkname))
      (w2:log "paso 2: def obtenida")
      (vlax-for e blk
        (setq res
          (vl-catch-all-apply
            '(lambda ()
              (if (/= "AcDbAttributeDefinition" (vla-get-ObjectName e))
                (progn
                  (vla-GetBoundingBox e 'll 'ur)
                  ;; GetBoundingBox entrega SAFEARRAYS directos (no variants)
                  (setq p1 (vlax-safearray->list ll)
                        p2 (vlax-safearray->list ur))
                  (if (or (null minx) (< (car p1) minx)) (setq minx (car p1)))
                  (if (or (null miny) (< (cadr p1) miny)) (setq miny (cadr p1)))
                  (if (or (null maxx) (> (car p2) maxx)) (setq maxx (car p2)))
                  (if (or (null maxy) (> (cadr p2) maxy)) (setq maxy (cadr p2))))))))
        (if (vl-catch-all-error-p res)
          (w2:log (strcat "  bbox skip: " (vl-catch-all-error-message res)))))
      (if (not (and minx maxx))
        (w2:log "SIN BBOX")
        (progn
          (setq m 0.10
                cx (* 0.5 (+ minx maxx)) cy (* 0.5 (+ miny maxy))
                hw (+ m (* 0.5 (- maxx minx)))
                hh (+ m (* 0.5 (- maxy miny))))
          (w2:log (strcat "paso 3: bbox " (rtos (* 2 hw) 2 2) " x "
            (rtos (* 2 hh) 2 2) " centro (" (rtos cx 2 2) "," (rtos cy 2 2) ")"))
          (setq res (vl-catch-all-apply
            '(lambda ()
              (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
                '(100 . "AcDbPolyline") '(90 . 4) '(70 . 1)
                (cons 10 (list (- cx hw) (- cy hh)))
                (cons 10 (list (+ cx hw) (- cy hh)))
                (cons 10 (list (+ cx hw) (+ cy hh)))
                (cons 10 (list (- cx hw) (+ cy hh))))))))
          (if (vl-catch-all-error-p res)
            (w2:log (strcat "FALLO entmake poly: " (vl-catch-all-error-message res)))
            (progn
              (setq pl (entlast))
              (w2:log (strcat "paso 4: poly temporal " (vl-princ-to-string pl)))
              (setq res (vl-catch-all-apply 'vl-cmdf
                (list "_.WIPEOUT" "_P" pl "_Y")))
              (if (vl-catch-all-error-p res)
                (w2:log (strcat "FALLO comando WIPEOUT: "
                  (vl-catch-all-error-message res)))
                (w2:log (strcat "paso 5: WIPEOUT cmd res "
                  (vl-princ-to-string res))))
              (setq went (entlast))
              (w2:log (strcat "paso 6: entlast tipo "
                (vl-princ-to-string (cdr (assoc 0 (entget went))))))
              (cond
                ((and went (= (cdr (assoc 0 (entget went))) "WIPEOUT"))
                  (setq wobj (vlax-ename->vla-object went))
                  (setq res (vl-catch-all-apply 'vla-CopyObjects
                    (list doc (urb:object-array-variant (list wobj)) blk)))
                  (if (vl-catch-all-error-p res)
                    (w2:log (strcat "FALLO CopyObjects: "
                      (vl-catch-all-error-message res)))
                    (w2:log "paso 7: copiado al def"))
                  (entdel went)
                  (setq copied nil)
                  (vlax-for e blk
                    (if (= "AcDbWipeout" (vla-get-ObjectName e)) (setq copied e)))
                  (if copied
                    (progn
                      (setq res (vl-catch-all-apply
                        '(lambda ()
                          (setq table (urb:sortents-table blk))
                          (vla-MoveToBottom table
                            (urb:object-array-variant (list copied))))))
                      (if (vl-catch-all-error-p res)
                        (w2:log (strcat "FALLO sortents: "
                          (vl-catch-all-error-message res)))
                        (w2:log "paso 8: wipeout al fondo del def OK")))
                    (w2:log "FALLO: copia no encontrada en def")))
                (T
                  (w2:log "FALLO: no se creo WIPEOUT; borrando poly")
                  (if (and pl (entget pl)) (entdel pl))))))
          (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))))
          (if ss
            (progn
              (setq res (vl-catch-all-apply 'vl-cmdf
                (list "_.DRAWORDER" ss "" "_Front")))
              (w2:log (strcat "paso 9: draworder "
                (itoa (sslength ss)) " accs "
                (if (vl-catch-all-error-p res) "FALLO" "OK")))))
          (vl-catch-all-apply 'vla-Regen (list doc 1))))))
  (w2:log "FIN-WIPEACC2")
  (princ))
(princ "\nwipeacc2 listo")(princ)
