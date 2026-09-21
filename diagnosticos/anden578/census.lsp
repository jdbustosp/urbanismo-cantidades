(vl-load-com)
(setq c578:dir "C:/Users/juanbusper/Documents/URBANISMO/work/anden578_20260921"
      c578:out (strcat c578:dir "/census578.txt"))

(defun c578:log (text / stream)
  (setq stream (open c578:out "a"))
  (write-line text stream)
  (close stream))

(defun c578:chain-max-deviation (chain / a b p d best)
  (setq a (car chain) b (last chain) best 0.0)
  (foreach p chain
    (setq d (urb:dist-point-seg p a b))
    (if (> d best) (setq best d)))
  best)

(defun c578:edge-summary (chain / edges edge text)
  (setq text "")
  (foreach edge (urb:open-chain-edges chain)
    (setq text
      (strcat text
        (if (= text "") "" ",")
        (rtos (nth 2 edge) 2 3) "m@"
        (rtos (/ (* (nth 3 edge) 180.0) pi) 2 2))))
  text)

(defun c578:run (/ blocks en pts clean corners chains chain maxlen len drift dev bbox obj)
  (c578:log (strcat "VERSION " *urb-version*))
  (c578:log (strcat "DWG " (getvar "DWGNAME")))
  (setq blocks (urb:all-anden-blocks))
  (c578:log (strcat "ANDENES " (itoa (length blocks))))
  (foreach en blocks
    (setq pts (urb:anden-block-points en)
          clean (urb:dedupe-ring-points pts)
          corners (urb:polygon-corner-indices clean (* pi (/ 45.0 180.0)))
          chains (urb:polygon-chains-at-corners clean corners)
          maxlen 0.0)
    (foreach chain chains
      (setq len (urb:chain-total-length chain))
      (if (> len maxlen) (setq maxlen len)))
    (foreach chain chains
      (setq len (urb:chain-total-length chain))
      (if (> len (max 5.0 (* 0.25 maxlen)))
        (progn
          (setq drift (/ (* (urb:chain-direction-drift chain) 180.0) pi)
                dev (c578:chain-max-deviation chain))
          (if (> drift 1.0)
            (progn
              (setq obj (vlax-ename->vla-object en)
                    bbox (urb:object-box-points obj))
              (c578:log
                (strcat "HANDLE=" (cdr (assoc 5 (entget en)))
                  " NAME=" (cdr (assoc 2 (entget en)))
                  " LEN=" (rtos len 2 3)
                  " DRIFT=" (rtos drift 2 3)
                  " DEV=" (rtos dev 2 4)
                  " BOX=" (vl-princ-to-string bbox)
                  " EDGES=" (c578:edge-summary chain)))))))))
  (c578:log "FINISHED"))

(if (findfile c578:out) (vl-file-delete c578:out))
(setq c578:result (vl-catch-all-apply 'c578:run nil))
(if (vl-catch-all-error-p c578:result)
  (c578:log (strcat "ERROR " (vl-catch-all-error-message c578:result))))
(princ)
