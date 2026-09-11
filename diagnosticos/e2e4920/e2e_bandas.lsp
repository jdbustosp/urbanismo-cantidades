;; Diagnostico (2026-09-11, Claude): por que se pierden las bandas del anden
;; que cruzan los bordillos del acceso vehicular.
(setq lab (getenv "URB_TEST_LAB"))
(setq *e2e-out* (open (strcat lab "/bandas.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(defun emsg (r) (if (vl-catch-all-error-p r) (vl-catch-all-error-message r) "ok"))

(setq *e2e-err*
  (vl-catch-all-apply
    '(lambda () (load (strcat (getenv "URB_REPO") "/urbanismo_cantidades.lsp")))))
(if (vl-catch-all-error-p *e2e-err*)
  (progn (elog (strcat "ERROR-CARGA " (emsg *e2e-err*))) (elog "DONE") (close *e2e-out*))
  (progn
    (elog (strcat "motor " *urb-version*))
    (defun mk-poly (pts / data)
      (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
        '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))
    (defun caras (reg / ex it n)
      (setq ex (vl-catch-all-apply 'vla-Explode (list (vla-Copy reg))) n 0)
      (if (vl-catch-all-error-p ex) -1
        (progn
          (foreach it (urb:variant-object-list ex)
            (if (= (vla-get-ObjectName it) "AcDbRegion") (setq n (1+ n)))
            (urb:safe-delete it))
          n)))
    ;; acceso sin anden: solo crea los prefabricados
    (setq en-acc (mk-poly (list '(2.0 0.0) '(12.0 0.0) '(12.0 3.3) '(2.0 3.3))))
    (setq fr (urb:ramp-auto-frames en-acc))
    (setq acc (vl-catch-all-apply 'urb:build-contour-ramp
                (list en-acc fr "RAMPA-VEHICULAR" "1" "1" "Concreto")))
    (elog (strcat "acceso: " (emsg acc)))
    ;; region base del anden 14 x 4 menos cortadores
    (setq en-anden (mk-poly (list '(0.0 0.0) '(14.0 0.0) '(14.0 4.0) '(0.0 4.0))))
    (setq base (urb:add-region-from-object (vla-Copy (vlax-ename->vla-object en-anden))))
    (elog (strcat "base area " (rtos (vla-get-Area base) 2 3)))
    (setq base (urb:apply-anden-cutouts base))
    (elog (strcat "base recortada area " (rtos (vla-get-Area base) 2 3)
                  " caras " (itoa (caras base))))
    (foreach b '((0.0 0.8) (1.8 2.6) (2.6 3.6) (5.0 5.8) (8.0 8.8) (11.4 12.4))
      (setq st (urb:clip-stripe-once base (car b) (cadr b) -2.0 6.0 0.0))
      (if (null st)
        (elog (strcat "banda " (rtos (car b) 2 1) ": clip NIL"))
        (progn
          (setq h (vl-catch-all-apply 'vla-AddHatch (list (urb:space) 1 "SOLID" :vlax-true)))
          (setq r (vl-catch-all-apply
                    '(lambda () (vla-AppendOuterLoop h (urb:make-loop-array st))
                                (vla-Evaluate h) h)))
          (elog (strcat "banda " (rtos (car b) 2 1) ": area "
                  (rtos (vla-get-Area st) 2 3) " caras " (itoa (caras st))
                  " | hatch " (emsg r)
                  (if (vl-catch-all-error-p r) ""
                    (strcat " area hatch " (rtos (vla-get-Area h) 2 3)))))
          (if (vl-catch-all-error-p r) (urb:safe-delete h))
          ;; alternativa: una por cara
          (setq ex (vl-catch-all-apply 'vla-Explode (list (vla-Copy st))) okc 0 tot 0)
          (if (not (vl-catch-all-error-p ex))
            (foreach it (urb:variant-object-list ex)
              (if (= (vla-get-ObjectName it) "AcDbRegion")
                (progn
                  (setq tot (1+ tot))
                  (setq h (vl-catch-all-apply 'vla-AddHatch (list (urb:space) 1 "SOLID" :vlax-true)))
                  (setq r (vl-catch-all-apply
                            '(lambda () (vla-AppendOuterLoop h (urb:make-loop-array it))
                                        (vla-Evaluate h) h)))
                  (if (vl-catch-all-error-p r) (urb:safe-delete h) (setq okc (1+ okc))))
                (urb:safe-delete it))))
          (elog (strcat "   por caras: " (itoa okc) "/" (itoa tot) " con hatch")))))
    (elog "DONE")
    (close *e2e-out*)))
