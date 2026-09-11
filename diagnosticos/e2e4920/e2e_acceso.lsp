;; E2E real + RENDER (2026-09-11, Claude): acceso vehicular como superposicion
;; sobre un anden, igual que el plano. Se construye un anden con su patron,
;; se pone encima el acceso y se vuelca la geometria para dibujarla y
;; compararla con el render del plano (r_vehicular.png).

(setq lab (getenv "URB_TEST_LAB"))
(setq *e2e-out* (open (strcat lab "/acceso.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(setq *e2e-fallos* 0)
(defun echk (nombre ok detalle)
  (if ok
    (elog (strcat "OK   " nombre (if detalle (strcat " | " detalle) "")))
    (progn
      (setq *e2e-fallos* (1+ *e2e-fallos*))
      (elog (strcat "FALLO " nombre (if detalle (strcat " | " detalle) "")))))
  ok)
(defun cuenta (filtro / ss) (setq ss (ssget "_X" filtro)) (if ss (sslength ss) 0))

(setq *e2e-err*
  (vl-catch-all-apply
    '(lambda () (load (strcat (getenv "URB_REPO") "/urbanismo_cantidades.lsp")))))

(if (vl-catch-all-error-p *e2e-err*)
  (progn
    (elog (strcat "ERROR-CARGA " (vl-catch-all-error-message *e2e-err*)))
    (elog "DONE") (close *e2e-out*))
  (progn
    (elog (strcat "motor " *urb-version* " cargado"))
    (defun mk-poly (pts / data)
      (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
        '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))

    ;; ---- 1) ANDEN de 14 x 4 m; el bordillo de la via es y = 0 ----
    (setq en-anden (mk-poly (list '(0.0 0.0) '(14.0 0.0) '(14.0 4.0) '(0.0 4.0))))
    (setq *urb-current-tactile-side-point* '(7.0 -1.0))
    (urb:set-anden-data en-anden "Loseta" "1" "1" "No" "No"
      "20 x 20 cm" "Si" "SUP_TN" "Via creada")
    (urb:set-anden-pattern-mode en-anden "AUTOMATICO")
    (setq ok1 (vl-catch-all-apply
      '(lambda () (urb:build-anden-finish en-anden "Loseta" "No" "No" "20 x 20 cm"))))
    (setq anden (if (and ok1 (not (vl-catch-all-error-p ok1)))
      (vl-catch-all-apply '(lambda () (urb:package-anden en-anden)))))
    (echk "anden base construido y empacado"
      (and anden (not (vl-catch-all-error-p anden))) "")
    (setq area-anden0 (if (and anden (not (vl-catch-all-error-p anden)))
      (atof (urb:safe-string (cdr (assoc "AREA_M2" (urb:block-attribute-values anden))) "0")) 0.0))
    (elog (strcat "AREA_M2 del anden antes del acceso = " (rtos area-anden0 2 3)))

    ;; ---- 2) ACCESO VEHICULAR de 10 x 3,3 m encima (x 2..12) ----
    ;; primer borde dibujado = el del bordillo (y = 0)
    (setq en-acc (mk-poly (list '(2.0 0.0) '(12.0 0.0) '(12.0 3.3) '(2.0 3.3))))
    (setq fr (vl-catch-all-apply 'urb:ramp-auto-frames (list en-acc)))
    (setq n-pre0 (cuenta '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
    (setq acc
      (if (and fr (not (vl-catch-all-error-p fr)))
        (vl-catch-all-apply 'urb:build-contour-ramp
          (list en-acc fr "RAMPA-VEHICULAR" "1" "1" "Concreto"))))
    (echk "acceso vehicular creado"
      (and acc (not (vl-catch-all-error-p acc)))
      (if (and acc (vl-catch-all-error-p acc)) (vl-catch-all-error-message acc) "ok"))
    (setq n-pre1 (cuenta '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
    (elog (strcat "prefabricados de bordillo creados = " (itoa (- n-pre1 n-pre0))))
    (echk "las dos aletas y la banda salen como BORDILLOS prefabricados (3)"
      (= 3 (- n-pre1 n-pre0)) (itoa (- n-pre1 n-pre0)))
    ;; las aletas tienen que ser CURVAS (bulge en su referencia)
    (setq ssp (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))) i 0 curvas 0)
    (if ssp
      (repeat (sslength ssp)
        (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                   (vla-get-Name (urb:as-vla-object (ssname ssp i)))))
        (setq tiene nil)
        (vlax-for o bd
          (if (and (= (vla-get-ObjectName o) "AcDbPolyline")
                   (urb:lwpoly-has-arcs-p (vlax-vla-object->ename o)))
            (setq tiene T)))
        (if tiene (setq curvas (1+ curvas)))
        (setq i (1+ i))))
    (echk "las aletas son bordillos CURVOS (2 con arco)" (= curvas 2) (itoa curvas))
    ;; el acceso NO es cortador: el anden no se recorta en todo el modulo
    (setq cort nil)
    (foreach en (urb:anden-cutout-blocks)
      (if (urb:string-equal-p (car (urb:get-xdata-strings en "URB_RAMPA_BLOCK"))
            "RAMPA-VEHICULAR")
        (setq cort T)))
    (echk "el modulo del acceso NO es cortador (es superposicion)" (not cort) "")
    ;; el anden se recorto SOLO bajo los bordillos
    (setq ssa (ssget "_X" '((0 . "INSERT") (-3 ("URB_ANDEN_BLOCK")))))
    (setq area-anden1 (if ssa
      (atof (urb:safe-string (cdr (assoc "AREA_M2"
        (urb:block-attribute-values (ssname ssa 0)))) "0")) 0.0))
    (elog (strcat "AREA_M2 del anden despues = " (rtos area-anden1 2 3)
      " (bajo " (rtos (- area-anden0 area-anden1) 2 3) " m2)"))
    (echk "el anden se recorto bajo los bordillos, no en todo el acceso"
      (and (> (- area-anden0 area-anden1) 0.5)
           (< (- area-anden0 area-anden1) 5.0))
      (strcat "bajo " (rtos (- area-anden0 area-anden1) 2 3) " m2"))
    ;; las franjas gris/blanca del anden tienen que seguir cubriendo TODO
    ;; el anden neto (tambien las que cortan las aletas y la banda A-80)
    (if ssa
      (progn
        (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                   (vla-get-Name (urb:as-vla-object (ssname ssa 0)))))
        (setq a-fr 0.0 n-fr 0)
        (vlax-for o bd
          (if (and (= (vla-get-ObjectName o) "AcDbHatch")
                   (= (strcase (vla-get-PatternName o)) "SOLID")
                   (member (vla-get-Layer o)
                     '("URB-ANDEN-LOSETA-GRIS-20X20" "URB-ANDEN-BLOQUE-BLANCO-20X10")))
            (setq a-fr (+ a-fr (vla-get-Area o)) n-fr (1+ n-fr))))
        (elog (strcat "franjas del anden: " (itoa n-fr) " rellenos, "
                (rtos a-fr 2 3) " m2"))
        (echk "las franjas del anden cubren todo el anden neto (no se pierden bajo el acceso)"
          (equal a-fr area-anden1 0.15)
          (strcat (rtos a-fr 2 3) " de " (rtos area-anden1 2 3)))))
    (if (and acc (not (vl-catch-all-error-p acc)))
      (progn
        (setq att (urb:block-attribute-values acc))
        (elog (strcat "acceso: AREA_M2 (bajada) = "
          (urb:safe-string (cdr (assoc "AREA_M2" att)) "?")
          " | BOLARDO_UND = " (urb:safe-string (cdr (assoc "BOLARDO_UND" att)) "?")
          " | BORDILLO_PREFAB_UND = "
          (urb:safe-string (cdr (assoc "BORDILLO_PREFAB_UND" att)) "?")))
        (echk "la bajada tiene area" (> (atof (urb:safe-string
          (cdr (assoc "AREA_M2" att)) "0")) 5.0)
          (urb:safe-string (cdr (assoc "AREA_M2" att)) "?"))))

    ;; ---- 3) volcado para el render ----
    (load (strcat lab "/dumplib.lsp"))
    (setq *o* (open (strcat lab "/dump_acceso.txt") "w"))
    (setq rv (vl-catch-all-apply 'ventana (list "acceso" -1.0 -1.0 15.0 5.0 T)))
    (if (vl-catch-all-error-p rv)
      (elog (strcat "ERROR en el volcado: " (vl-catch-all-error-message rv))))
    (close *o*)
    (elog "volcado listo: dump_acceso.txt")

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
