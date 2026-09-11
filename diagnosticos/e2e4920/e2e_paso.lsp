;; E2E + RENDER (2026-09-11, Claude): paso peatonal LARGO. Se crea un paso de
;; 12 x 4 m y se vuelca para compararlo con la foto 5 del usuario / el plano.
(setq lab (getenv "URB_TEST_LAB"))
(setq *e2e-out* (open (strcat lab "/paso.txt") "w"))
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
  (urb:safe-string (cdr (assoc tag (urb:block-attribute-values ref))) ""))

(setq *e2e-err*
  (vl-catch-all-apply
    '(lambda () (load (strcat (getenv "URB_REPO") "/urbanismo_cantidades.lsp")))))
(if (vl-catch-all-error-p *e2e-err*)
  (progn (elog (strcat "ERROR-CARGA " (vl-catch-all-error-message *e2e-err*)))
         (elog "DONE") (close *e2e-out*))
  (progn
    (elog (strcat "motor " *urb-version* " cargado"))
    (defun mk-poly (pts / data)
      (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
        '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))
    ;; paso de 12 x 4: los remates son los lados cortos (x = 0 y x = 12)
    (setq en-paso (mk-poly (list '(0.0 0.0) '(12.0 0.0) '(12.0 4.0) '(0.0 4.0))))
    (setq fp (vl-catch-all-apply 'urb:ramp-auto-frames (list en-paso)))
    (elog (strcat "remates: " (if (vl-catch-all-error-p fp) (vl-catch-all-error-message fp)
                                (itoa (length fp)))))
    (setq paso (if (and fp (not (vl-catch-all-error-p fp)))
      (vl-catch-all-apply 'urb:build-contour-ramp
        (list en-paso fp "PASO-PEATONAL" "1" "1" "Adoquin"))))
    (echk "paso creado" (and paso (not (vl-catch-all-error-p paso)))
      (if (vl-catch-all-error-p paso) (vl-catch-all-error-message paso) "ok"))
    (if (and paso (not (vl-catch-all-error-p paso)))
      (progn
        (foreach tg '("AREA_M2" "BORDILLO_ML" "TOPEROL_ML" "A81_UND" "MATERIAL"
                      "LOSETA_LISA_M2" "LOSETA_LISA_UND" "ADOQUIN_M2" "ADOQUIN_20X10_UND"
                      "LOSETA_GUIA_ML" "LOSETA_GUIA_UND" "LOSETA_TOPEROL_UND"
                      "SBG_M3" "ARENA_M3" "GEOTEXTIL_M2")
          (elog (strcat tg " = " (att paso tg))))
        ;; cuadre: 12 x 4 = 48 m2 = bandas 38,24 + guia 3,44 + toperol 2,80
        ;;          + A81 1,56 + bordillos 1,96 (sin traslapes)
        (setq lo (atof (att paso "LOSETA_LISA_M2")) ad (atof (att paso "ADOQUIN_M2")))
        (echk "bandas (loseta + adoquin) = 38,24 m2: no pisan bordillos, A81, toperol ni guia"
          (equal (+ lo ad) 38.24 0.05) (rtos (+ lo ad) 2 3))
        (echk "hay loseta Y adoquin" (and (> lo 5.0) (> ad 5.0))
          (strcat (rtos lo 2 2) " / " (rtos ad 2 2)))
        (echk "guia por el eje entre las dos alertas: 8,60 ml"
          (equal (atof (att paso "LOSETA_GUIA_ML")) 8.60 0.05) (att paso "LOSETA_GUIA_ML"))
        (echk "toperol: laterales 1,50 x 4 + alerta 4,00 x 2 = 14,00 ml"
          (equal (atof (att paso "TOPEROL_ML")) 14.0 0.01) (att paso "TOPEROL_ML"))
        (echk "AREA_M2 = bandas + guia + toperol = 44,48"
          (equal (atof (att paso "AREA_M2")) 44.48 0.05) (att paso "AREA_M2"))
        (echk "A81: 4" (= "4" (att paso "A81_UND")) (att paso "A81_UND"))
        (echk "SBG = AREA x 0,50" (equal (atof (att paso "SBG_M3"))
          (* 0.5 (atof (att paso "AREA_M2"))) 0.01) (att paso "SBG_M3"))
        ;; la bajada: tono translucido y texto BAJA en el bloque
        (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                   (vla-get-Name (urb:as-vla-object paso))))
        (setq n-baja 0 n-txt 0 n-guia 0)
        (vlax-for o bd
          (if (= (vla-get-Layer o) "URB-RAMPA-BAJADA")
            (progn (setq n-baja (1+ n-baja))
                   (if (= (vla-get-ObjectName o) "AcDbText") (setq n-txt (1+ n-txt)))))
          (if (= (vla-get-Layer o) "URB-ANDEN-LOSETA-GUIA-20X20") (setq n-guia (1+ n-guia))))
        (echk "bajada marcada en los dos extremos (BAJA x2)" (= n-txt 2) (itoa n-txt))
        (echk "guia dibujada (region + relleno + barras)" (>= n-guia 6) (itoa n-guia))))
    ;; ---- PASO QUEBRADO (como la foto 5): eje (0,20)-(7,20)-(13,24), ancho 3,5
    (setq cl (vlax-ename->vla-object
               (entmakex (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                               '(90 . 3) '(70 . 0) '(10 0.0 20.0) '(10 7.0 20.0) '(10 13.0 24.0)))))
    (setq o1 (car (vlax-safearray->list (vlax-variant-value (vla-Offset cl 1.75))))
          o2 (car (vlax-safearray->list (vlax-variant-value (vla-Offset cl -1.75)))))
    (setq pq (append (urb:lwpoly-points (vlax-vla-object->ename o1))
                     (reverse (urb:lwpoly-points (vlax-vla-object->ename o2)))))
    (vla-Delete cl) (vla-Delete o1) (vla-Delete o2)
    (setq en-q (mk-poly (mapcar '(lambda (p) (list (car p) (cadr p))) pq)))
    (setq fq (vl-catch-all-apply 'urb:ramp-auto-frames (list en-q)))
    (elog (strcat "quebrado: remates "
            (if (vl-catch-all-error-p fq) (vl-catch-all-error-message fq)
              (if fq (strcat (rtos (nth 3 (car fq)) 2 2) " y " (rtos (nth 3 (cadr fq)) 2 2)) "NIL"))))
    (setq pasoq (if (and fq (not (vl-catch-all-error-p fq)))
      (vl-catch-all-apply 'urb:build-contour-ramp
        (list en-q fq "PASO-PEATONAL" "1" "1" "Adoquin"))))
    (echk "paso quebrado creado" (and pasoq (not (vl-catch-all-error-p pasoq)))
      (if (vl-catch-all-error-p pasoq) (vl-catch-all-error-message pasoq) "ok"))
    (if (and pasoq (not (vl-catch-all-error-p pasoq)))
      (progn
        (foreach tg '("AREA_M2" "LOSETA_LISA_M2" "ADOQUIN_M2" "LOSETA_GUIA_ML" "TOPEROL_ML")
          (elog (strcat "quebrado " tg " = " (att pasoq tg))))
        ;; eje real = 7 + 7,21 = 14,21; menos los dos extremos de 1,70
        (echk "la guia sigue el quiebre (~10,8 ml)"
          (< 9.8 (atof (att pasoq "LOSETA_GUIA_ML")) 11.8) (att pasoq "LOSETA_GUIA_ML"))
        ;; cobertura sin huecos ni traslapes en el quiebre: bandas = contorno
        ;; - guia - toperol (2,60) - A81 (1,56) - bordillos (1,76)
        (setq aq (vla-get-Area (vlax-ename->vla-object en-q))
              bq (+ (atof (att pasoq "LOSETA_LISA_M2")) (atof (att pasoq "ADOQUIN_M2")))
              gq (* 0.04 (atof (att pasoq "LOSETA_GUIA_UND"))))
        (echk "bandas del paso quebrado cubren todo sin traslapes"
          (equal bq (- aq gq 2.60 1.56 1.76) 0.10)
          (strcat (rtos bq 2 3) " vs " (rtos (- aq gq 2.60 1.56 1.76) 2 3)))))

    ;; ---- filas de presupuesto de los pasos ----
    (setq filas (vl-catch-all-apply 'urb:ppto-rows-rampas))
    (echk "exportacion de rampas sin error" (not (vl-catch-all-error-p filas))
      (if (vl-catch-all-error-p filas) (vl-catch-all-error-message filas)
        (strcat (itoa (length filas)) " filas")))
    (if (and filas (not (vl-catch-all-error-p filas)))
      (progn
        (setq conceptos nil)
        (foreach f filas
          (if (and (listp f) (= (type (nth 1 f)) 'STR))
            (progn
              (elog (strcat "fila: " (nth 0 f) " | " (nth 1 f) " | " (nth 7 f) " "
                      (rtos (nth 8 f) 2 3)))
              (setq conceptos (cons (nth 1 f) conceptos)))))
        (echk "salen loseta, adoquin, SBG, geotextil y arena"
          (and (member "Loseta lisa 20x20x6" conceptos)
               (member "Adoquin gris 10x20x6" conceptos)
               (member "Subbase granular SBG" conceptos)
               (member "Geotextil tejido 2100" conceptos)
               (member "Arena de nivelacion" conceptos)) "")))

    (load (strcat lab "/dumplib.lsp"))
    (setq *o* (open (strcat lab "/dump_paso.txt") "w"))
    (setq rv (vl-catch-all-apply 'ventana (list "quebrado" -2.0 16.0 15.0 28.0 T)))
    (setq rv (vl-catch-all-apply 'ventana (list "paso" -1.0 -1.0 13.0 5.0 T)))
    (if (vl-catch-all-error-p rv) (elog (strcat "ERROR volcado " (vl-catch-all-error-message rv))))
    (close *o*)
    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
