(in-package #:org.shirakumo.fraf.leaf)

(defun decline ()
  (invoke-restart 'decline))

(defstruct (block (:constructor make-block (s)))
  (s 0 :type (unsigned-byte 16)))

(defstruct (ground (:include block)
                   (:constructor make-ground (s))))

(defstruct (platform (:include block)
                     (:constructor make-platform (s))))

(defstruct (spike (:include block)
                  (:constructor make-spike (s))))

(defstruct (slope (:include block)
                  (:constructor make-slope (s l r)))
  (l 0 :type (unsigned-byte 16))
  (r 0 :type (unsigned-byte 16)))

(defun make-surface-blocks (t-s slope-steps)
  (let ((blocks (make-array (+ 4 (* 2 (reduce #'+ slope-steps)))))
        (i -1))
    (flet ((make (c &rest args)
             (setf (aref blocks (incf i)) (apply (find-symbol (format NIL "MAKE-~a" c)) t-s args))))
      (make 'block)
      (make 'ground)
      (make 'platform)
      (make 'spike)
      (loop for steps in slope-steps
            do (loop for i from 0 below steps
                     for l = (* (/ i steps) +tile-size+)
                     for r = (* (/ (1+ i) steps) +tile-size+)
                     do (make 'slope (floor l) (floor r)))
            do (loop for i downfrom steps above 0
                     for l = (* (/ i steps) +tile-size+)
                     for r = (* (/ (1- i) steps) +tile-size+)
                     do (make 'slope (floor l) (floor r))))
      blocks)))

(sb-ext:defglobal +surface-blocks+ NIL)
(setf +surface-blocks+ (make-surface-blocks +tile-size+ '(1 2 3)))

(defstruct (hit (:constructor make-hit (object time location normal)))
  (object NIL)
  (time 0.0 :type single-float)
  (location NIL :type vec2)
  (normal NIL :type vec2))

(defun aabb (seg-pos seg-vel aabb-pos aabb-size)
  (declare (type vec2 seg-pos seg-vel aabb-pos aabb-size))
  (sb-int:with-float-traps-masked (:overflow :underflow :inexact)
    (let* ((scale (vec2 (if (= 0 (vx seg-vel)) most-positive-single-float (/ (vx seg-vel)))
                        (if (= 0 (vy seg-vel)) most-positive-single-float (/ (vy seg-vel)))))
           (sign (vec2 (float-sign (vx seg-vel)) (float-sign (vy seg-vel))))
           (near (v* (v- (v- aabb-pos (v* sign aabb-size)) seg-pos) scale))
           (far  (v* (v- (v+ aabb-pos (v* sign aabb-size)) seg-pos) scale)))
      (unless (or (< (vy far) (vx near))
                  (< (vx far) (vy near)))
        (let ((t-near (max (vx near) (vy near)))
              (t-far (min (vx far) (vy far))))
          (when (and (< t-near 1)
                     (< 0 t-far))
            (let* ((time (alexandria:clamp t-near 0.0 1.0))
                   (normal (if (< (vy near) (vx near))
                               (vec (- (vx sign)) 0)
                               (vec 0 (- (vy sign))))))
              (unless (= 0 (v. normal seg-vel))
                ;; KLUDGE: This test is necessary in order to ignore vertical edges
                ;;         that seem to stick out of the blocks. I have no idea why.
                (unless (and (/= 0 (vy normal))
                             (<= (vx aabb-size) (abs (- (vx aabb-pos) (vx seg-pos)))))
                  (make-hit NIL time aabb-pos normal))))))))))
