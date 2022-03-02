(in-package #:org.shirakumo.fraf.kandria)

(defmethod handle ((ev quit-game) (controller controller)))

(define-action-set in-editor)
(define-action undo (in-editor)
  (key-press (and (one-of key :z)
                  (retained :control))))

(define-action redo (in-editor)
  (key-press (and (one-of key :y)
                  (retained :control))))

(define-action-set in-menu (exclusive-action-set))
(define-action skip (in-menu))
(define-action advance (in-menu))
(define-action previous (in-menu))
(define-action next (in-menu))
(define-action accept (in-menu))
(define-action back (in-menu))

(define-action toggle-editor ())
(define-action toggle-menu ())
(define-action screenshot ())
(define-action report-bug ())
(define-action toggle-fullscreen ())
(define-action toggle-diagnostics ())

(define-action-set in-game (exclusive-action-set))
(define-action quickmenu (in-game))
(define-action open-map (in-game))
(define-action interact (in-game))
(define-action jump (in-game))
(define-action dash (in-game directional-action))
(define-action climb (in-game))
(define-action crawl (in-game))
(define-action light-attack (in-game))
(define-action heavy-attack (in-game))
(define-action left (in-game analog-action))
(define-action right (in-game analog-action))
(define-action up (in-game analog-action))
(define-action down (in-game analog-action))

(define-action-set fishing (exclusive-action-set))
(define-action cast-line (fishing))
(define-action reel-in (fishing))
(define-action stop-fishing (fishing))

(define-action-set in-map (exclusive-action-set))
(define-action pan-left (in-map))
(define-action pan-right (in-map))
(define-action pan-up (in-map))
(define-action pan-down (in-map))
(define-action zoom-in (in-map))
(define-action zoom-out (in-map))
(define-action close-map (in-map))
(define-action toggle-trace (in-map))
(define-action toggle-marker (in-map))
