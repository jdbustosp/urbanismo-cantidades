;; E2E real v4.89.0 (Claude, 2026-09-10): "si dibujo un paso peatonal sobre
;; algo que ya esta dibujado, que me borre lo que quedaria por debajo, para
;; que no quede doble area". Se dibuja una zona verde y un anden, se pone
;; un paso peatonal ENCIMA y se comprueba que las areas de los vecinos
;; bajan exactamente en lo que ocupa el paso.

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/recorte.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(setq *e2e-fallos* 0)
(defun echk (nombre ok detalle)
  (if ok
    (elog (strcat "OK   " nombre (if detalle (strcat " | " detalle) "")))
    (progn
      (setq *e2e-fallos* (1+ *e2e-fallos*))
      (elog (strcat "FALLO " nombre (if detalle (strcat " | " detalle) "")))))
  ok)
(defun att (ref tag)
  (atof (urb:safe-string
    (cdr (assoc tag (urb:block-attribute-values ref))) "0")))

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
      (setq data
        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
          '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))

    ;; ---- 0) SARDINEL CURVO que pasa por debajo del paso ----
    ;; referencia curva de 20 m con un arco real (bulge), como el sardinel
    ;; de una via en curva; antes el recorte se lo saltaba por ser curvo.
    (setq en-ref
      (entmakex
        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
              '(90 . 3) '(70 . 0) '(8 . "URB-PREFAB")
              '(10 0.0 5.0) '(42 . 0.15)
              '(10 10.0 5.6) '(42 . 0.15)
              '(10 20.0 5.0))))
    (setq pre
      (vl-catch-all-apply 'urb:build-prefab-from-reference
        (list en-ref (list 10.0 20.0 0.0) "Sardinel" 0.20 "1" "1"
              "Exterior" "Via")))
    (echk "sardinel curvo creado"
      (and pre (not (vl-catch-all-error-p pre)))
      (if (and pre (vl-catch-all-error-p pre))
        (vl-catch-all-error-message pre) "ok"))
    (setq n-pre0 (if (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
                   (sslength ss) 0))
    (setq ml0 (if (and pre (not (vl-catch-all-error-p pre))) (att pre "LONGITUD_M") 0.0))
    (elog (strcat "sardineles antes = " (itoa n-pre0) " | ML = " (rtos ml0 2 3)))

    ;; ---- 1) ZONA VERDE con BORDE CURVO ----
    ;; el lado de arriba lleva arco: si el recorte pierde el bulge, la zona
    ;; sale deformada (reporte del usuario).
    (setq en-zv
      (entmakex
        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
              '(90 . 4) '(70 . 1)
              '(10 0.0 0.0) '(42 . 0.0)
              '(10 20.0 0.0) '(42 . 0.0)
              '(10 20.0 10.0) '(42 . 0.12)
              '(10 0.0 10.0) '(42 . 0.0))))
    (setq zv-arco0 (vla-get-Area (urb:as-vla-object en-zv)))
    (urb:prepare-green-layers)
    (setq obj (urb:as-vla-object en-zv))
    (vla-put-Layer obj "URB-ZONA-VERDE")
    (setq hz (vl-catch-all-apply 'urb:add-hatch
               (list obj "URB-ZONA-VERDE" "SOLID" 1 "SOLID" 1.0 3)))
    (if (vl-catch-all-error-p hz) (setq hz nil))
    (setq zv (vl-catch-all-apply 'urb:package-green-zone
               (list en-zv hz "1" "1" 0.20)))
    (echk "zona verde creada"
      (and zv (not (vl-catch-all-error-p zv)))
      (if (and zv (vl-catch-all-error-p zv)) (vl-catch-all-error-message zv) "ok"))
    (setq zv-area0 (if (and zv (not (vl-catch-all-error-p zv))) (att zv "AREA_M2") 0.0))
    (elog (strcat "zona verde AREA_M2 inicial = " (rtos zv-area0 2 3)))

    ;; ---- 2) PASO PEATONAL de 4 x 12 ENCIMA de la zona verde ----
    ;; ocupa x 6..10, y -1..11 -> el solape con la zona verde es 4 x 10 = 40 m2
    (setq en-paso (mk-poly (list '(6.0 -1.0) '(10.0 -1.0) '(10.0 11.0) '(6.0 11.0))))
    (setq fr (vl-catch-all-apply 'urb:ramp-auto-frames (list en-paso)))
    (echk "remates del paso detectados"
      (and (not (vl-catch-all-error-p fr)) fr (= 2 (length fr)))
      (if (vl-catch-all-error-p fr) (vl-catch-all-error-message fr)
        (if fr (strcat (rtos (nth 3 (car fr)) 2 2) " y "
                (rtos (nth 3 (cadr fr)) 2 2)) "NIL")))
    (setq paso
      (if (and fr (not (vl-catch-all-error-p fr)))
        (vl-catch-all-apply 'urb:build-contour-ramp
          (list en-paso fr "PASO-PEATONAL" "1" "1" "Adoquin"))))
    (echk "paso peatonal creado"
      (and paso (not (vl-catch-all-error-p paso)))
      (if (and paso (vl-catch-all-error-p paso))
        (vl-catch-all-error-message paso) "ok"))

    ;; ---- 3) el modulo entra como CORTADOR ----
    (setq cortadores (urb:anden-cutout-blocks))
    (setq hay-rampa nil)
    (foreach en cortadores
      (if (wcmatch (strcase (urb:safe-string
                              (vla-get-Name (urb:as-vla-object en)) ""))
                   "URB_RAMPA_*")
        (setq hay-rampa T)))
    (echk "el modulo de paso queda registrado como cortador"
      hay-rampa (strcat (itoa (length cortadores)) " cortadores"))

    ;; ---- 3b) diagnostico de las dos piezas del recorte ----
    (if (and paso (not (vl-catch-all-error-p paso)))
      (progn
        (setq fp (vl-catch-all-apply 'urb:block-footprint-region
                   (list (urb:as-vla-object paso))))
        (elog (strcat "huella del modulo de paso = "
          (if (vl-catch-all-error-p fp) (vl-catch-all-error-message fp)
            (if fp (rtos (vla-get-Area fp) 2 3) "NIL"))))
        (echk "el modulo tiene huella utilizable como cortador"
          (and fp (not (vl-catch-all-error-p fp)))
          (if (and fp (not (vl-catch-all-error-p fp)))
            (rtos (vla-get-Area fp) 2 3) "NIL"))
        (if (and fp (not (vl-catch-all-error-p fp))) (urb:safe-delete fp))))
    (setq ssz (ssget "_X" '((0 . "INSERT") (-3 ("URB_GREEN_BLOCK")))))
    (if ssz
      (progn
        (setq cont (vl-catch-all-apply 'urb:explode-green-block-boundary
                     (list (ssname ssz 0))))
        (elog (strcat "contorno desempacado de la zona verde = "
          (if (vl-catch-all-error-p cont) (vl-catch-all-error-message cont)
            (if cont (rtos (vla-get-Area (urb:as-vla-object cont)) 2 3) "NIL"))))
        (if (and cont (not (vl-catch-all-error-p cont)))
          (progn
            ;; sonda directa del booleano, para ver donde se pierde
            (setq rg (urb:add-region-from-object
                       (vla-Copy (urb:as-vla-object cont))))
            (setq ct (urb:block-footprint-region (urb:as-vla-object paso)))
            (elog (strcat "  sonda: region " (rtos (vla-get-Area rg) 2 3)
              " | cortador " (rtos (vla-get-Area ct) 2 3)))
            (setq bb1 (vl-catch-all-apply
              '(lambda ( / lo hi) (vla-GetBoundingBox rg 'lo 'hi)
                 (list (vlax-safearray->list lo) (vlax-safearray->list hi)))))
            (setq bb2 (vl-catch-all-apply
              '(lambda ( / lo hi) (vla-GetBoundingBox ct 'lo 'hi)
                 (list (vlax-safearray->list lo) (vlax-safearray->list hi)))))
            (elog (strcat "  bbox region  = " (vl-princ-to-string bb1)))
            (elog (strcat "  bbox cortador= " (vl-princ-to-string bb2)))
            (elog (strcat "  se solapan? = "
              (if (urb:objects-bbox-overlap-p rg ct 0.02) "SI" "NO")))
            ;; lo que de verdad usa urb:apply-anden-cutouts: el INSERT
            (setq ins (urb:as-vla-object paso))
            (setq bb3 (vl-catch-all-apply
              '(lambda ( / lo hi) (vla-GetBoundingBox ins 'lo 'hi)
                 (list (vlax-safearray->list lo) (vlax-safearray->list hi)))))
            (elog (strcat "  bbox del INSERT = " (vl-princ-to-string bb3)))
            (elog (strcat "  region vs INSERT se solapan? = "
              (if (urb:objects-bbox-overlap-p rg ins 0.02) "SI" "NO")))
            (setq nc 0)
            (foreach e (urb:anden-cutout-blocks) (setq nc (1+ nc)))
            (elog (strcat "  cortadores vistos = " (itoa nc)))
            (setq rg2 (urb:add-region-from-object
                        (vla-Copy (urb:as-vla-object cont))))
            (setq rg2 (vl-catch-all-apply 'urb:apply-anden-cutouts (list rg2)))
            ;; ESTE es el area neta de referencia: el contorno menos TODOS
            ;; los cortadores (el paso y tambien el sardinel, que ocupa su
            ;; propia franja y tampoco se debe contar dos veces).
            (setq zv-neta (if (vl-catch-all-error-p rg2) 0.0 (vla-get-Area rg2)))
            (elog (strcat "  urb:apply-anden-cutouts -> " (rtos zv-neta 2 3)))
            (if (not (vl-catch-all-error-p rg2)) (urb:safe-delete rg2))
            (setq bo (vl-catch-all-apply 'vla-Boolean (list rg 2 ct)))
            (elog (strcat "  boolean solo con el paso = "
              (if (vl-catch-all-error-p bo) (vl-catch-all-error-message bo) "ok")
              " | area = "
              (rtos (vl-catch-all-apply 'vla-get-Area (list rg)) 2 3)))
            (urb:safe-delete rg)
            (setq cl (vl-catch-all-apply 'urb:clip-poly-loops (list cont 0.05)))
            (elog (strcat "urb:clip-poly-loops -> "
              (if (vl-catch-all-error-p cl) (vl-catch-all-error-message cl)
                (strcat (itoa (length cl)) " pedazo(s)"))))
            (urb:safe-delete (urb:as-vla-object cont))))))

    ;; ---- 4) RECORTE de lo que quedo debajo ----
    (if (and paso (not (vl-catch-all-error-p paso)))
      (progn
        (setq res (vl-catch-all-apply 'urb:recut-vecinos-bajo
                    (list (urb:as-ename paso))))
        (echk "urb:recut-vecinos-bajo corrio"
          (not (vl-catch-all-error-p res))
          (if (vl-catch-all-error-p res) (vl-catch-all-error-message res)
            (vl-princ-to-string res)))
        (if (not (vl-catch-all-error-p res))
          (progn
            (echk "recorto la zona verde" (= 1 (cadr res))
              (strcat (itoa (cadr res)) " zona(s) recortada(s)"))
            ;; el paso cruza la zona de lado a lado: tiene que quedar en DOS
            (setq ss (ssget "_X" '((0 . "INSERT") (-3 ("URB_GREEN_BLOCK")))))
            (setq zv-area1 0.0 i 0)
            (if ss
              (repeat (sslength ss)
                (setq zv-area1 (+ zv-area1 (att (ssname ss i) "AREA_M2")))
                (setq i (1+ i))))
            (elog (strcat "zonas verdes en el dibujo = "
              (if ss (itoa (sslength ss)) "0")
              " | area sumada = " (rtos zv-area1 2 3)
              " | area neta medida con el booleano = " (rtos zv-neta 2 3)))
            (echk "queda al menos una zona verde"
              (and ss (>= (sslength ss) 1))
              (if ss (itoa (sslength ss)) "0"))
            (echk "el area de las zonas resultantes = el area neta real"
              (< (abs (- zv-area1 zv-neta)) 0.5)
              (strcat (rtos zv-area1 2 3) " vs " (rtos zv-neta 2 3)))
            (echk "y NO quedo doble area"
              (< zv-area1 (- zv-area0 30.0))
              (strcat (rtos zv-area0 2 2) " -> " (rtos zv-area1 2 2)))
            ;; el arco del borde superior tiene que sobrevivir al recorte
            (setq con-arco 0 i 0)
            (if ss
              (repeat (sslength ss)
                (setq bdz (vla-Item (vla-get-Blocks (urb:doc))
                            (vla-get-Name (urb:as-vla-object (ssname ss i)))))
                (vlax-for o bdz
                  (if (and (= (vla-get-ObjectName o) "AcDbPolyline")
                           (urb:lwpoly-has-arcs-p (vlax-vla-object->ename o)))
                    (setq con-arco (1+ con-arco))))
                (setq i (1+ i))))
            (elog (strcat "zonas verdes con arco conservado = " (itoa con-arco)))
            (echk "el recorte NO deformo el borde curvo de la zona verde"
              (> con-arco 0) (strcat (itoa con-arco) " con arco"))
            ;; ---- y los SARDINELES ----
            (setq ssp (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))))
            (setq ml1 0.0 i 0)
            (if ssp
              (repeat (sslength ssp)
                (setq ml1 (+ ml1 (att (ssname ssp i) "LONGITUD_M")))
                (setq i (1+ i))))
            (elog (strcat "sardineles despues = "
              (if ssp (itoa (sslength ssp)) "0") " | ML = " (rtos ml1 2 3)
              " (antes " (rtos ml0 2 3) ")"))
            (echk "el sardinel CURVO tambien se recorto bajo el paso"
              (< ml1 (- ml0 3.0))
              (strcat (rtos ml0 2 2) " -> " (rtos ml1 2 2)))
            (echk "el sardinel quedo partido en dos tramos"
              (and ssp (= 2 (sslength ssp)))
              (if ssp (itoa (sslength ssp)) "0"))))))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
