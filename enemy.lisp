(in-package #:org.shirakumo.fraf.leaf)

(define-shader-subject enemy (lit-animated-sprite movable facing-entity solid)
  ((vertex-array :initform (asset 'leaf '16x))
   (bsize :initform (nv/ (vec 16 16) 2))
   (size :initform (vec 16 16))
   (texture :initform (asset 'leaf 'placeholder)))
  (:default-initargs
   :animations '((idle :start 0 :end 1 :step 0.1))))

(defmethod die ((enemy enemy))
  (leave enemy (surface enemy)))

(defmethod tick :before ((enemy enemy) ev)
  (let ((collisions (collisions enemy))
        (vel (velocity enemy))
        (acc (acceleration enemy)))
    (if (svref collisions 2)
        (nv* acc (damp* 0.9 100 (dt ev)))
        (decf (vy acc) (* +vgrav+ 20 (dt ev))))
    (when (<= (vlength acc) 0.01)
      (vsetf acc 0 0))
    (nvclamp (v- +vlim+) acc +vlim+)
    (nv+ vel acc)))

(defmethod tick :after ((enemy enemy) ev)
  (unless (contained-p (location enemy) (surface enemy))
    (vsetf (location enemy)
           (vx (location (surface enemy)))
           (vy (location (surface enemy))))))
