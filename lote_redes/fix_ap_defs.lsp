;; FIX defs BTAP (2026-08-26): la FASE F del lote AP borraba circulos
;; DENTRO del vlax-for sobre la misma definicion -- la coleccion se
;; salta entidades al mutarla iterando y varias polilineas quedaron
;; gordas/cortas. Version correcta: recolectar primero, mutar despues,
;; VERIFICAR al final def por def.
(vl-load-com)
(defun fa:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_ap_defs_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c:FIXAPDEFS (/ blks blk nb distv circs pls atts e on lin fixed bad
                    tienelv n ss i obj txt)
  (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
  (setq fixed 0 bad 0)
  (vlax-for blk blks
    (setq nb (vla-get-Name blk))
    (if (wcmatch nb "MP_TRAMO_BTAP_*,MP_TRAMO_MT_*")
      (progn
        (setq distv (atof (vl-string-translate "_" "."
          (substr nb
            (if (vl-string-search "BTAP_" nb)
              (+ 6 (vl-string-search "BTAP_" nb))
              (+ 4 (vl-string-search "MT_" nb)))))))
        ;; 1) RECOLECTAR (sin mutar)
        (setq circs nil pls nil atts nil tienelv nil)
        (vlax-for e blk
          (setq on (vla-get-ObjectName e))
          (cond
            ((= on "AcDbCircle") (setq circs (cons e circs)))
            ((= on "AcDbPolyline") (setq pls (cons e pls)))
            ((= on "AcDbAttributeDefinition")
              (setq atts (cons e atts))
              (if (= (strcase (vla-get-TagString e)) "LONG_VIS")
                (setq tienelv T)))))
        ;; 2) MUTAR
        (foreach e circs (vl-catch-all-apply 'vla-Delete (list e)))
        (foreach e pls
          (vl-catch-all-apply 'vla-put-ConstantWidth (list e 0.20))
          (setq lin (entget (vlax-vla-object->ename e)))
          (setq lin (subst (cons 10 (list 0.0 0.0)) (assoc 10 lin) lin))
          (entmod
            (reverse
              (subst (cons 10 (list distv 0.0))
                (assoc 10 (reverse lin)) (reverse lin)))))
        (foreach e atts
          (if (> (vla-get-Height e) 0.9) (vla-put-Height e 0.9)))
        (if (null tienelv)
          (mp:center-visible-att
            (mp:vla-add-att blk "LONG_VIS" "Longitud visible" ""
              (list (/ distv 2.0) -1.25 0.0) 0.9 nil
              (if (vl-string-search "BTAP" nb)
                "PPTO-ELECTRICA-BT-AP" "PPTO-ELECTRICA-MT")
              (if (vl-string-search "BTAP" nb) 2 6))
            (list (/ distv 2.0) -1.25 0.0) 0.9))
        (vl-cmdf "_.ATTSYNC" "_N" nb)
        ;; 3) VERIFICAR
        (setq lin nil)
        (vlax-for e blk
          (if (= (vla-get-ObjectName e) "AcDbPolyline")
            (progn
              (setq txt (entget (vlax-vla-object->ename e)))
              (if (or (> (cdr (assoc 43 txt)) 0.25)
                      (> (abs (cadr (assoc 10 txt))) 0.01))
                (setq lin T)))))
        (if lin
          (progn (setq bad (1+ bad))
            (fa:log (strcat "  SIGUE MAL: " nb)))
          (setq fixed (1+ fixed))))))
  (fa:log (strcat "Defs normalizadas OK: " (itoa fixed) " | aun mal: " (itoa bad)))
  ;; etiquetas LONG_VIS de instancia vacias
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_BTAP_*,MP_TRAMO_MT_*"))))
  (setq n (if ss (sslength ss) 0) i 0)
  (while (< i n)
    (setq obj (vlax-ename->vla-object (ssname ss i)))
    (setq txt "")
    (foreach e (vlax-invoke obj 'GetAttributes)
      (if (= (strcase (vla-get-TagString e)) "LONGITUD")
        (setq txt (vla-get-TextString e))))
    (foreach e (vlax-invoke obj 'GetAttributes)
      (if (and (= (strcase (vla-get-TagString e)) "LONG_VIS")
               (= (vla-get-TextString e) ""))
        (vla-put-TextString e (strcat "L=" txt))))
    (setq i (1+ i)))
  (fa:log (strcat "Instancias revisadas: " (itoa n)))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (fa:log "FIXAPDEFS-TERMINADO"))
(c:FIXAPDEFS)
