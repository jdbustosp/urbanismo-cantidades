;; E2E real (2026-09-10, Claude): la RAMPA VEHICULAR tiene que salir con la
;; composicion del plano de detalles (B-RAMPA VEHICULAR), no con el modulo
;; peatonal. Se contrasta contra las medidas leidas del DWG:
;;   aleta trapezoidal de 2,369 en el bordillo y 2,156 al fondo
;;   fondo de rampa 1,70 | banda de fondo 0,20 (bordillo A-80)
;;   tableta podotactil de alerta al fondo y por los dos costados
;;   4 bolardos por extremo

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/rampav.txt") "w"))
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

    ;; medidas puras contra el plano
    (echk "la aleta del plano es de 2,369 m"
      (equal 2.369 *urb-rampav-aleta* 1e-9) (rtos *urb-rampav-aleta* 2 3))
    (echk "el fondo de la rampa es de 1,70 m"
      (equal 1.70 *urb-rampav-fondo* 1e-9) (rtos *urb-rampav-fondo* 2 3))
    (echk "un acceso de 10 m usa la aleta completa del plano"
      (equal 2.369 (urb:rampav-aleta 10.0) 1e-9)
      (rtos (urb:rampav-aleta 10.0) 2 3))
    (echk "un acceso angosto reparte la aleta sin dejar de dibujarse"
      ((lambda (a) (and (> a 0.29) (< a 2.369))) (urb:rampav-aleta 4.0))
      (rtos (urb:rampav-aleta 4.0) 2 3))

    ;; acceso vehicular de 10,00 x 6,00 (el frente del plano)
    (setq en-veh
      (mk-poly (list '(0.0 0.0) '(10.0 0.0) '(10.0 6.0) '(0.0 6.0))))
    (setq fr (vl-catch-all-apply 'urb:ramp-auto-frames (list en-veh)))
    (echk "remates detectados"
      (and (not (vl-catch-all-error-p fr)) fr (= 2 (length fr)))
      (if (vl-catch-all-error-p fr) (vl-catch-all-error-message fr)
        (if fr (strcat (rtos (nth 3 (car fr)) 2 2) " y "
                (rtos (nth 3 (cadr fr)) 2 2)) "NIL")))
    (setq veh
      (if (and fr (not (vl-catch-all-error-p fr)))
        (vl-catch-all-apply 'urb:build-contour-ramp
          (list en-veh fr "RAMPA-VEHICULAR" "1" "1" "Concreto"))))
    (echk "acceso vehicular creado"
      (and veh (not (vl-catch-all-error-p veh)))
      (if (and veh (vl-catch-all-error-p veh))
        (vl-catch-all-error-message veh) "ok"))

    (if (and veh (not (vl-catch-all-error-p veh)))
      (progn
        (elog (strcat "AREA_M2 = " (att veh "AREA_M2")
          " | BORDILLO_A80_ML = " (att veh "BORDILLO_A80_ML")
          " | TOPEROL_ML = " (att veh "TOPEROL_ML")
          " | BOLARDO_UND = " (att veh "BOLARDO_UND")
          " | A81_UND = " (att veh "A81_UND")))
        ;; el A-80 de fondo mide (Ltapa - 2*aleta) por extremo
        (setq Lt (nth 3 (car fr)))
        (setq a80esp (* 2.0 (- Lt (* 2.0 (urb:rampav-aleta Lt)))))
        (echk "el bordillo A-80 de fondo se cuenta"
          (< (abs (- a80esp (atof (att veh "BORDILLO_A80_ML")))) 0.02)
          (strcat (att veh "BORDILLO_A80_ML") " esperado " (rtos a80esp 2 3)))
        (echk "quedan los 4 bolardos por extremo (8 en total)"
          (= "8" (att veh "BOLARDO_UND")) (att veh "BOLARDO_UND"))
        (echk "el acceso vehicular ya NO usa la pieza A81 del modulo peatonal"
          (= "0" (att veh "A81_UND")) (att veh "A81_UND"))
        ;; inventario del bloque
        (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                   (vla-get-Name (urb:as-vla-object veh))))
        (setq n-rem 0 n-bor 0 n-tab 0 n-cir 0 n-pun 0 pn nil)
        (vlax-for o bd
          (cond
            ((= (vla-get-Layer o) "URB-RAMPA-REMATE")
              (setq n-rem (1+ n-rem))
              (if (= (vla-get-ObjectName o) "AcDbCircle") (setq n-cir (1+ n-cir))))
            ((= (vla-get-Layer o) "URB-BORDILLO") (setq n-bor (1+ n-bor)))
            ((= (vla-get-Layer o) "URB-ANDEN-LOSETA-TOPEROL-20X20")
              (setq n-tab (1+ n-tab))
              (if (= (vla-get-ObjectName o) "AcDbHatch")
                (progn
                  (setq pn (vl-catch-all-apply 'vla-get-PatternName (list o)))
                  (if (and (= (type pn) 'STR)
                           (vl-string-search "TOPEROL" (strcase pn)))
                    (setq n-pun (1+ n-pun))))))))
        (elog (strcat "bloque: remate=" (itoa n-rem) " (circulos " (itoa n-cir)
          ") | bordillo=" (itoa n-bor) " | tableta=" (itoa n-tab)
          " (punteadas " (itoa n-pun) ")"))
        (echk "los bolardos quedan dibujados como circulos"
          (= n-cir 8) (itoa n-cir))
        (echk "hay banda de bordillo A-80 en los dos extremos"
          (>= n-bor 4) (itoa n-bor))
        (echk "hay tableta podotactil de alerta con su punteado"
          (and (>= n-tab 6) (> n-pun 0))
          (strcat (itoa n-tab) " piezas / " (itoa n-pun) " punteadas"))))

    ;; ---- PASO PEATONAL LARGO: cuerpo con la textura de bandas ----
    (setq en-paso
      (mk-poly (list '(40.0 0.0) '(52.0 0.0) '(52.0 4.0) '(40.0 4.0))))
    (setq fp (vl-catch-all-apply 'urb:ramp-auto-frames (list en-paso)))
    (setq paso
      (if (and fp (not (vl-catch-all-error-p fp)))
        (vl-catch-all-apply 'urb:build-contour-ramp
          (list en-paso fp "PASO-PEATONAL" "1" "1" "Adoquin"))))
    (echk "paso peatonal largo creado"
      (and paso (not (vl-catch-all-error-p paso)))
      (if (and paso (vl-catch-all-error-p paso))
        (vl-catch-all-error-message paso) "ok"))
    (if (and paso (not (vl-catch-all-error-p paso)))
      (progn
        (setq bd (vla-Item (vla-get-Blocks (urb:doc))
                   (vla-get-Name (urb:as-vla-object paso))))
        (setq b-gris 0 b-blanco 0 n-ret 0)
        (vlax-for o bd
          (if (= (vla-get-Layer o) "URB-RAMPA")
            (cond
              ((member (vla-get-ObjectName o) '("AcDbRegion"))
                (cond ((= 8 (vla-get-Color o)) (setq b-gris (1+ b-gris)))
                      ((= 7 (vla-get-Color o)) (setq b-blanco (1+ b-blanco)))))
              ((= (vla-get-ObjectName o) "AcDbHatch")
                (setq n-ret (1+ n-ret))))))
        (elog (strcat "cuerpo del paso: bandas grises=" (itoa b-gris)
          " blancas=" (itoa b-blanco) " | hatches=" (itoa n-ret)))
        (echk "el cuerpo del paso quedo con la textura por bandas del anden"
          (and (> b-gris 1) (> b-blanco 1))
          (strcat (itoa b-gris) " gris / " (itoa b-blanco) " blanco"))
        (echk "cada banda lleva sus juntas"
          (>= n-ret (+ b-gris b-blanco)) (itoa n-ret))))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
