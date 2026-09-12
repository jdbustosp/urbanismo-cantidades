;; E2E (2026-09-11, Claude): rampa vehicular con el detalle completo cuando
;; NO hay anden debajo (pedido del usuario: "no me aparece detallada toda la
;; rampa, tiene que verse como la imagen 2"), superposicion cuando SI hay,
;; prefabricados A-105 con su capa, zona verde en el presupuesto y las filas
;; de rampa con el vocabulario del libro.
(setq lab (getenv "URB_TEST_LAB"))
(setq *e2e-out* (open (strcat lab "/veh3p.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(setq *e2e-fallos* 0)
(defun echk (nombre ok detalle)
  (if ok (elog (strcat "OK   " nombre (if detalle (strcat " | " detalle) "")))
    (progn (setq *e2e-fallos* (1+ *e2e-fallos*))
      (elog (strcat "FALLO " nombre (if detalle (strcat " | " detalle) "")))))
  ok)
(defun att (ref tag)
  (urb:safe-string (cdr (assoc tag (urb:block-attribute-values ref))) ""))

(setq *e2e-err* (vl-catch-all-apply
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

    ;; ---- 1) acceso vehicular SIN anden debajo (10 x 4) ----
    (setq en1 (mk-poly (list '(0.0 0.0) '(10.0 0.0) '(10.0 4.0) '(0.0 4.0))))
    (setq f1 (urb:ramp-auto-frames en1))
    (setq v1 (vl-catch-all-apply 'urb:build-contour-ramp
               (list en1 f1 "RAMPA-VEHICULAR" "1" "1" "Concreto")))
    (echk "acceso vehicular creado sin anden" (and v1 (not (vl-catch-all-error-p v1)))
      (if (vl-catch-all-error-p v1) (vl-catch-all-error-message v1) "ok"))
    (if (and v1 (not (vl-catch-all-error-p v1)))
      (progn
        (foreach tg '("AREA_M2" "AREA_BAJADA_M2" "LONGITUD_MAYOR_M"
                      "LONGITUD_MENOR_M" "LOSETA_LISA_M2" "ADOQUIN_M2"
                      "LOSETA_GUIA_ML" "LOSETA_TOPEROL_UND"
                      "BORDILLO_A80_ML" "SARDINEL_A85_ML" "BOLARDO_UND" "SBG_M3")
          (elog (strcat "  " tg " = " (att v1 tg))))
        ;; longitudes de la foto acotada: mayor 10,00 / menor 5,80
        (echk "longitud mayor 10,00 y longitud menor 5,80"
          (and (equal (atof (att v1 "LONGITUD_MAYOR_M")) 10.0 0.01)
               (equal (atof (att v1 "LONGITUD_MENOR_M")) 5.80 0.01))
          (strcat (att v1 "LONGITUD_MAYOR_M") " / " (att v1 "LONGITUD_MENOR_M")))
        (echk "el sardinel A-85 cubre la longitud mayor"
          (equal (atof (att v1 "SARDINEL_A85_ML")) 10.0 0.01)
          (att v1 "SARDINEL_A85_ML"))
        (echk "el bordillo A-80 son las dos curvas mas la longitud menor"
          (> (atof (att v1 "BORDILLO_A80_ML")) 5.80)
          (att v1 "BORDILLO_A80_ML"))
        (echk "el modulo dibuja su propio pavimento (loseta y adoquin)"
          (and (> (atof (att v1 "LOSETA_LISA_M2")) 3.0)
               (> (atof (att v1 "ADOQUIN_M2")) 3.0))
          (strcat (att v1 "LOSETA_LISA_M2") " / " (att v1 "ADOQUIN_M2")))
        (echk "lleva franja de guia podotactil a 2,50 m del bordillo"
          (> (atof (att v1 "LOSETA_GUIA_ML")) 9.0) (att v1 "LOSETA_GUIA_ML"))
        (setq ssp (ssget "_X" '((0 . "INSERT") (-3 ("URB_PREFAB_BLOCK")))) i 0
              n85 0 nbor 0 capas "" dest "")
        (repeat (if ssp (sslength ssp) 0)
          (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                     (vla-get-Name (urb:as-vla-object (ssname ssp i)))))
          (vlax-for o bd
            (if (not (vl-string-search (vla-get-Layer o) capas))
              (setq capas (strcat capas " " (vla-get-Layer o)))))
          (setq atp (urb:block-attribute-values (ssname ssp i)))
          (setq tp (urb:safe-string (cdr (assoc "TIPO" atp)) ""))
          (if (not (vl-string-search
                     (urb:safe-string (cdr (assoc "DESTINO_PPTO" atp)) "?") dest))
            (setq dest (strcat dest " ["
              (urb:safe-string (cdr (assoc "DESTINO_PPTO" atp)) "?") "]")))
          (if (wcmatch (strcase tp) "*A-85*") (setq n85 (1+ n85)) (setq nbor (1+ nbor)))
          (setq i (1+ i)))
        (elog (strcat "  prefabricados: " (itoa n85) " sardinel A-85 + "
                (itoa nbor) " bordillo A-80 | capas:" capas
                " | destinos:" dest))
        (echk "las curvas y la longitud menor son bordillo A-80 (3 piezas)"
          (and (= nbor 3) (vl-string-search "URB-BORDILLO" capas))
          (strcat (itoa nbor) " piezas A-80"))
        (echk "la longitud mayor es un sardinel A-85 en su capa"
          (and (= n85 1) (vl-string-search "URB-SARDINEL-A-85" capas))
          (strcat (itoa n85) " pieza A-85"))
        (echk "los prefabricados del modulo se cobran en el capitulo de la rampa"
          (and (vl-string-search "Rampa vehicular" dest)
               (not (vl-string-search "Anden" dest)))
          dest)
        ;; los bolardos M-63 en su propia capa
        (setq bd (vla-Item (vla-get-Blocks (urb:doc)) (vla-get-Name v1)) nbol 0)
        (vlax-for o bd
          (if (and (= (vla-get-ObjectName o) "AcDbCircle")
                   (= (vla-get-Layer o) "URB-BOLARDO-M-63"))
            (setq nbol (1+ nbol))))
        (echk "los 4 bolardos M-63 van en la capa URB-BOLARDO-M-63"
          (= nbol 4) (itoa nbol))))

    ;; ---- 1b) el frente marcado con los 3 puntos manda sobre el lado largo ----
    (setq enf (mk-poly (list '(0.0 20.0) '(3.0 20.0) '(3.0 26.0) '(0.0 26.0))))
    (setq *urb-rampav-frente* '(1.5 20.0))
    (setq cf (vl-catch-all-apply 'urb:vehicular-curb-frame (list enf)))
    (echk "con 3 puntos el frente es el borde marcado, no el lado mas largo"
      (and cf (not (vl-catch-all-error-p cf))
           (equal (urb:ramp-frame-mid (car cf)) '(1.5 20.0) 0.01)
           (equal (cadr cf) 6.0 0.01))
      (if (vl-catch-all-error-p cf) (vl-catch-all-error-message cf)
        (strcat "mid " (vl-princ-to-string (urb:ramp-frame-mid (car cf)))
          " fondo " (rtos (cadr cf) 2 2))))
    (setq *urb-rampav-frente* nil)
    (setq cf (vl-catch-all-apply 'urb:vehicular-curb-frame (list enf)))
    (echk "sin marca sigue el criterio de siempre (el lado mas largo)"
      (and cf (not (vl-catch-all-error-p cf)) (equal (nth 3 (car cf)) 6.0 0.01))
      (if (vl-catch-all-error-p cf) (vl-catch-all-error-message cf)
        (rtos (nth 3 (car cf)) 2 2)))
    (urb:safe-delete (urb:as-vla-object enf))

    ;; ---- 2) acceso vehicular SOBRE un anden: sigue siendo superposicion ----
    (setq ena (mk-poly (list '(30.0 0.0) '(44.0 0.0) '(44.0 4.0) '(30.0 4.0))))
    (setq *urb-current-tactile-side-point* '(37.0 -1.0))
    (urb:set-anden-data ena "Loseta" "1" "1" "No" "No" "20 x 20 cm" "Si" "SUP_TN" "Via creada")
    (urb:set-anden-pattern-mode ena "AUTOMATICO")
    (urb:build-anden-finish ena "Loseta" "No" "No" "20 x 20 cm")
    (setq anden (urb:package-anden ena))
    (setq en2 (mk-poly (list '(32.0 0.0) '(42.0 0.0) '(42.0 3.3) '(32.0 3.3))))
    (setq f2 (urb:ramp-auto-frames en2))
    (setq v2 (vl-catch-all-apply 'urb:build-contour-ramp
               (list en2 f2 "RAMPA-VEHICULAR" "1" "1" "Concreto")))
    (echk "acceso vehicular sobre anden creado" (and v2 (not (vl-catch-all-error-p v2))) "")
    (if (and v2 (not (vl-catch-all-error-p v2)))
      (echk "sobre un anden NO duplica el pavimento (superposicion)"
        (and (= 0.0 (atof (att v2 "LOSETA_LISA_M2")))
             (= 0.0 (atof (att v2 "ADOQUIN_M2"))))
        (strcat "loseta " (att v2 "LOSETA_LISA_M2") " adoquin " (att v2 "ADOQUIN_M2"))))
    ;; en superposicion el anden ya cobra subrasante/excavacion/granulares:
    ;; el modulo NO las puede volver a cobrar
    (setq frs (vl-catch-all-apply 'urb:ppto-rows-rampas) sup nil)
    (if (and frs (not (vl-catch-all-error-p frs)))
      (foreach f frs
        (if (and f (= (nth 9 f) (cdr (assoc 5 (entget (urb:as-ename v2)))))
                 (member (nth 1 f)
                   '("Compactacion de subrasante (Incluye nivelacion)"
                     "Subbase granular SBG" "Geotextil tejido 2100")))
          (setq sup (cons (nth 1 f) sup)))))
    (echk "en superposicion el modulo no repite la estructura del anden"
      (null sup) (if sup (vl-princ-to-string sup) "ninguna fila repetida"))

    ;; ---- 3) zona verde en el presupuesto ----
    (setq zv (vl-catch-all-apply 'urb:build-green-from-points
               (list (list (cons '(60.0 0.0) 0.0) (cons '(70.0 0.0) 0.0)
                           (cons '(70.0 5.0) 0.0) (cons '(60.0 5.0) 0.0))
                     "1" "1" 0.20)))
    (echk "zona verde creada" (and zv (not (vl-catch-all-error-p zv)))
      (if (vl-catch-all-error-p zv) (vl-catch-all-error-message zv) "ok"))
    (setq fzv (vl-catch-all-apply 'urb:ppto-rows-zonasverdes))
    (echk "la zona verde llega al presupuesto"
      (and (not (vl-catch-all-error-p fzv)) fzv (> (length fzv) 0))
      (if (vl-catch-all-error-p fzv) (vl-catch-all-error-message fzv)
        (strcat (itoa (length fzv)) " filas")))
    (if (and fzv (not (vl-catch-all-error-p fzv)))
      (foreach f fzv (if f (elog (strcat "  ZV: " (nth 0 f) " | " (nth 1 f) " | "
        (nth 7 f) " " (rtos (nth 8 f) 2 3))))))

    ;; ---- 4) filas de rampa con el vocabulario del libro ----
    (setq fr (vl-catch-all-apply 'urb:ppto-rows-rampas))
    (echk "filas de rampa sin error" (not (vl-catch-all-error-p fr))
      (if (vl-catch-all-error-p fr) (vl-catch-all-error-message fr)
        (strcat (itoa (length fr)) " filas")))
    (if (and fr (not (vl-catch-all-error-p fr)))
      (progn
        (setq conc nil cand nil)
        (foreach f fr
          (if f (progn
            (elog (strcat "  " (nth 0 f) ": " (nth 1 f) " | " (nth 7 f) " "
                    (rtos (nth 8 f) 2 3)))
            (if (= (car f) "RAMPA-VEHICULAR") (setq conc (cons (nth 1 f) conc)))
            (if (= (car f) "ANDEN") (setq cand (cons (nth 1 f) cand))))))
        ;; 2.2.4 solo tiene subrasante, excavacion, granulares, M.O. y bolardo
        (echk "el vehicular solo pide de 2.2.4 lo que 2.2.4 tiene"
          (and (member "Compactacion de subrasante (Incluye nivelacion)" conc)
               (member "Subbase granular SBG" conc)
               (member "M.O. instalacion de loseta guia y toperol" conc)
               (member "Suministro e instalacion de bolardo alto en hierro Tipo M-63" conc)
               (not (member "Adoquin gris 10x20x6" conc))
               (not (member "Loseta lisa 20x20x6" conc))
               (not (member "Arena de nivelacion" conc)))
          (strcat (itoa (length conc)) " actividades en 2.2.4"))
        ;; los materiales de pavimento los compra ANDENES
        (echk "los materiales que 2.2.4 no compra caen en ANDENES"
          (and (member "Adoquin gris 10x20x6" cand)
               (member "Loseta lisa 20x20x6" cand)
               (member "Arena de nivelacion" cand)
               (member "Transporte de prefabricados" cand))
          (strcat (itoa (length cand)) " actividades en ANDENES"))))
    (setq fp (vl-catch-all-apply 'urb:ppto-rows-prefabs))
    (if (and fp (not (vl-catch-all-error-p fp)))
      (progn
        (setq c2 nil c3 nil)
        (foreach f fp
          (if f (progn
            (elog (strcat "  PREF " (nth 0 f) ": " (nth 1 f) " | " (nth 7 f)
                    " " (rtos (nth 8 f) 2 3)))
            (setq c2 (cons (nth 1 f) c2))
            (if (= (nth 0 f) "RAMPA-VEHICULAR") (setq c3 (cons (nth 1 f) c3))))))
        (echk "el sardinel A-85 y el bordillo A-80 se cobran en 2.2.4"
          (and (member "Suministro sardinel bajo A-85 para rampa" c3)
               (member "M.O. instalacion de sardinel prefabricado" c3)
               (member "Bordillo prefabricado A-80" c3))
          (strcat (itoa (length fp)) " filas de prefabricados"))))

    ;; ---- 5) volcado para el render ----
    (load (strcat lab "/dumplib.lsp"))
    (setq *o* (open (strcat lab "/dump_veh3p.txt") "w"))
    (setq rv (vl-catch-all-apply 'ventana (list "veh3p" -1.0 -1.0 11.0 5.0 T)))
    (if (vl-catch-all-error-p rv) (elog (strcat "ERROR volcado " (vl-catch-all-error-message rv))))
    (close *o*)
    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
