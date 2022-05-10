;; -*- mode: poly-dialog; -*-
(in-package #:org.shirakumo.fraf.kandria)

(quest:define-quest (kandria q11-recruit-semis)
  :author "Tim White"
  :title "Recruit the Semis"
  :description "Fi wants me to speak with the Semi Sisters, and convince them to join us against the invading Wraw."
  :on-activate (task-reminder task-destination)

  ;; TODO okay for Fi not to have run/climb anims here? She could be plausibly through the door so quickly that critical path players won't notice, and they'll just assume she ran ahead of them
  ;; she also comes back when the player is in Wraw territory so they'll never see her then either  
  (task-reminder
   :title ""
   :invariant T
   :condition all-complete
   :visible NIL
   :on-activate T

   (:interaction interact-reminder
    :interactable fi
    :repeatable T
    :dialogue "
~ fi
| \"Go and see the Semi Sisters, and convince them to join us.\"(orange)
| (:unsure)As for me, I'm hoping Sahil is still around here somewhere.
"))

  (task-destination
   :title "Talk to Innis in Semi Sisters territory"
   :marker '(innis 500)
   :invariant T
   :condition all-complete
   :on-complete (q11a-bomb-recipe)
   :on-activate T

   (:interaction interact-innis
    :interactable innis
    :dialogue "
~ innis
| (:angry)Catherine still isn't here. What's the hold up?
~ player
- I thought you'd have bigger things to worry about.
  ~ innis
  | You mean the Wraw? It's in hand.
  | (:angry)Now run along - I've nothing more to say to you.
- She isn't coming.
  ~ innis
  | (:angry)Then I hope the Noka will enjoy drinking sand instead of water.
- We need to talk.
  ~ innis
  | (:angry)Unless you can explain why Catherine isn't here, I've nothing more to say to you.
~ islay
| (:unhappy)Sister! She isn't our enemy. The Noka are not our enemy.
~ innis
| (:angry)Shut up, Islay. Remember who's in charge.
| (:normal)And anyway, this time I dinnae ken why you're here, {(nametag player)}.
~ player
- I need your help.
  ~ innis
  | (:sly)What? An all-powerful android needs our help?
  | (:normal)I dinnae think so. More like Fi needs our help.
- We need your help.
  ~ innis
  | (:sly)More like Fi needs our help.
  | (:normal)You dinnae need our help - you're an android.
- We can help you.
  ~ innis
  | (:angry)The Noka? Help us? Dinnae make me laugh.
~ innis
| (:sly)... Oh, dinnae tell me you care for the Noka.
| I never understood why they gave androids emotions. Nothing but a distraction.
~ islay
| (:unhappy)Listen to her Innis, for Christ's sake!
~ innis
| (:angry)...
~ islay
| (:unhappy)The Wraw are on our doorstep. Somehow they're running interference on our network.
| We're deaf and blind.
~ innis
| (:angry)It's no' your call.
~ islay
| (:unhappy)Well why don't you ask our people? They see our cameras shutting down one by one, and our guns sat in storage.
| Just what exactly is your plan, sister?
~ innis
| (:angry)Are you saying you could do better?
~ islay
| (:unhappy)I'm saying we need help. We need the Noka - and we need {(nametag player)}.
~ innis
| (:angry)...
| Alright. Say we ally with the Noka. Then what?
~ islay
| We pool our resources - our weapons and people.
| We don't know the Wraw's exact numbers and capabilities, but I can hazard a guess from the hunters we sent. And how many came back.
~ player
| I've seen their mechs and supplies too - they're considerable.
~ islay
| Right. They are. But I think we stand a fighting chance if we work together.
| (:unhappy)... And we abandon our home.
~ innis
| (:angry)No. Never.
~ islay
| It's not forever. But the Wraw are already here, and we can't fight them alone.
| We load up a train and leave for the surface. Take as much as we can carry.
| Everything we leave behind is something the Wraw could use against us.
~ innis
| And what about the bomb?
~ player
- Bomb?
- Now you're talking.
- We blow them up!
~ islay
| I've improvised an explosive that could stop their advance. Collapse the tunnels completely - including the metro.
| ... We can still use it.
| But we're missing key components - (:unhappy)the hunters that survived barely got out with their lives, never mind the supplies we needed.
~ innis
| (:sly)Send the android while we evacuate.
~ islay
| (:normal)Aye, that might work. You'd need to go behind enemy lines.
| \"The Wraw hoard this kind of stuff\"(orange) - they should have plenty lying around.
| (:normal)We need \"blasting caps\"(orange) for the detonators, and \"charge packs\"(orange) for the explosive.
| I think \"10 of each\"(orange) should be enough, allowing for a few spares.
| Actually, make it \"20 charge packs\"(orange), just to be sure it has a big enough explosive yield.
| And you'll \"get paid for your efforts\"(orange): I'm a trader after all.
! eval (setf (var 'bomb-fee) 25)
~ player
- Thank you.
  ~ islay
  | It's alright - we value your work. I can give you \"25 parts per item\"(orange).
  | But don't thank me yet - this will be dangerous.
- There's no need.
  ~ islay
  | No, I insist. We value your work, and this will be dangerous.
  | I can give you \"25 parts per item\"(orange).
  ~ innis
  | ...
- How much?
  ~ innis
  | (:angry)...
  ~ islay
  | I can give you \"25 parts per item\"(orange).
  ~ player
  - Works for me.
    ~ islay
    | Okay then. We do value your work, and this will be dangerous.
  - Make it 50.
    ~ innis
    | (:angry)Fuck that! And what're ya gonna spend it on when the Wraw have rolled through here?
    ~ islay
    | (:nervous)If we stop them, life might return to normal.
    | (:normal)But we can't afford 50 - we need those parts. \"How about 35?\"(orange) We do value your work, and this will be dangerous.
    ~ player
    - Deal.
      ~ islay
      | Great, \"35 it is\"(orange).
      ! eval (setf (var 'bomb-fee) 35)
      ~ innis
      | (:angry)...
    - Actually 25 is fine.
      ~ innis
      | (:angry)...
      ~ islay
      | Alright then, \"25 it is\"(orange).
    - I've changed my mind: I'll take less than 25.
      ~ islay
      | No, I insist. This won't be easy, and \"25 is fair\"(orange).
      ~ innis
      | (:angry)...
  - I could take a little less, but not much.
    ~ islay
    | No, I insist. We value your work, and this will be dangerous. I think \"25 is fair\"(orange).
    ~ innis
    | ...
~ islay
| (:nervous)But please hurry.
| (:normal)We'll \"leave the metro running for now\"(orange) to help you - but the \"Wraw might use the tunnels to move their troops\"(orange).
~ innis
| (:angry)Or they'll derail the trains.
~ islay
| (:nervous)Let's hope they don't.
~ player
| I'll update Fi, then be on my way.
~ innis
| (:sly)That's right, you be a good dog.
~ islay
| (:unhappy)Innis!
| (:nervous)... You can't tell Fi - whatever the Wraw are doing to mess with our network, it affects your FFCS too.
~ player
- (Check FFCS)
  ~ player
  | \"Checking FFCS...\"(light-gray, italic)
  | (:embarassed)\"She's right. Shit.\"(light-gray, italic)
  ~ innis
  | (:sly)I think she just checked her FFCS.
  | (:angry)And you want us to trust you?
- (Trust Islay)
~ islay
| I'll explain everything to Fi once we reach the surface. \"Meet us there when you have the components.\"(orange)
| You got it? This is important.
~ player
- One more time.
  ~ islay
  | So: we need \"10 blasting caps\"(orange) and \"20 charge packs\"(orange).
  | You should find them in \"Wraw territory\"(orange). Then \"meet us at the Noka camp on the surface\"(orange).
- Got it.
~ islay
| Good luck, {(nametag player)}.
! eval (deactivate 'task-reminder)
! eval (activate 'q12-help-alex)
! eval (setf (location 'alex) 'alex-wraw-loc)
! setf (direction 'alex) 1
! eval (complete 'trader-semi-chat)
! eval (activate (unit 'bomb-cap-1))
! eval (activate (unit 'bomb-cap-2))
! eval (activate (unit 'bomb-cap-3))
! eval (activate (unit 'bomb-cap-4))
! eval (activate (unit 'bomb-cap-5))
! eval (activate (unit 'bomb-cap-6))
! eval (activate (unit 'bomb-charge-1))
! eval (activate (unit 'bomb-charge-2))
! eval (activate (unit 'bomb-charge-3))
! eval (activate (unit 'bomb-charge-4))
! eval (activate (unit 'bomb-charge-5))
")))
;; dinnae = don't / do not (Scottish)