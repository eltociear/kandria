(in-package #:org.shirakumo.fraf.leaf)

(defclass toolbar (alloy:structure)
  ())

(defmethod initialize-instance :after ((toolbar toolbar) &key editor entity)
  (let ((layout (make-instance 'alloy:horizontal-linear-layout
                               :cell-margins (alloy:margins 3 3)
                               :shapes (list (make-instance 'simple:filled-rectangle :bounds (alloy:margins)
                                                                                     :name :background))
                               :style `((:background :pattern ,(colored:color 0.1 0.1 0.1)))))
        (focus (make-instance 'alloy:focus-list)))
    (populate-toolbar layout focus editor entity)
    (alloy:finish-structure toolbar layout focus)))

(defmethod reinitialize-instance :after ((toolbar toolbar) &key editor entity)
  (let ((layout (alloy:layout-element toolbar))
        (focus (alloy:focus-element toolbar)))
    (alloy:clear layout)
    (alloy:clear focus)
    (populate-toolbar layout focus editor entity)))

(defun populate-toolbar (layout focus editor entity)
  (dolist (tool (applicable-tools entity))
    (let* ((tool (make-instance tool :editor editor))
           (button (make-instance 'alloy:button :data (make-instance 'alloy:value-data :value (label tool)))))
      (alloy:on alloy:activate (button)
        (setf (tool editor) tool))
      (alloy:enter button layout)
      (alloy:enter button focus))))
