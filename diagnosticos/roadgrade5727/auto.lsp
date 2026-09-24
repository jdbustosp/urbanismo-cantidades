(vl-load-com)
(setq rg27:out "C:/Users/juanbusper/Documents/URBANISMO/work/roadgrade5727/auto.txt")
(defun rg27:log (s / f) (setq f (open rg27:out "a")) (write-line s f) (close f))
(defun rg27:run (/ ss i e d axis p span start ref pts z chosen result)
  (setq ss (ssget "_X" '((-3 ("URB_VIA")))))
  (setq i 0)
  (if ss
    (while (and (< i (sslength ss)) (null chosen))
      (setq e (ssname ss i) i (1+ i)
            d (urb:get-xdata-strings e "URB_VIA"))
      (if (and (not (= (urb:safe-string (nth 1 d) "") "VIA-25"))
               (urb:grade-records-valid-p (urb:road-design-grade-records e d)))
        (progn
          (setq axis (urb:road-axis-recover e d (nth 22 d))
                start (atof (urb:safe-string (nth 21 d) "0"))
                span (atof (urb:safe-string (nth 18 d) "0")))
          (if (and axis (> span 4.0))
            (progn
              (setq p (vl-catch-all-apply 'vlax-curve-getPointAtDist
                        (list axis (+ start (* 0.5 span)))))
              (if (and p (not (vl-catch-all-error-p p)))
                (setq chosen e))))))))
  (rg27:log (strcat "ROAD " (if chosen (urb:safe-string (nth 1 d) "?") "NIL")))
  (if chosen
    (progn
      (setq pts (list (list (- (car p) 1.0) (- (cadr p) 1.0))
                      (list (+ (car p) 1.0) (- (cadr p) 1.0))
                      (list (+ (car p) 1.0) (+ (cadr p) 1.0))
                      (list (- (car p) 1.0) (+ (cadr p) 1.0))))
      (setq result (vl-catch-all-apply 'urb:area-grade-auto (list pts)))
      (if (vl-catch-all-error-p result)
        (rg27:log (strcat "FAIL area-grade-auto "
          (vl-catch-all-error-message result)))
        (progn
          (setq ref (if result (caddr (car result))))
          (setq z (if ref (vl-catch-all-apply 'urb:design-z-from-picks
                            (list result (car p) (cadr p)))))
          (rg27:log (strcat "REF " (if ref (urb:safe-string (nth 8 ref) "ANDEN") "NIL")
             " Z " (if (numberp z) (rtos z 2 4) "NIL")))
          (rg27:log (if (and ref (numberp z))
            "PASS perfil automatico de sendero/zona" "FAIL perfil automatico"))
          (if (and ref (numberp z)) (rg27:log "FINISHED")))))))
(rg27:run)
(princ)
