(ns cloft2.fast-dash
  (:use [cloft2.lib :only (later sec)])
  (:import [org.bukkit Bukkit Material]))

(def dash-id-table (atom {}))

(defn PlayerToggleSprintEvent [^org.bukkit.event.player.PlayerToggleSprintEvent evt]
  (let [player (-> evt .getPlayer)]
    (if (and (.isSprinting evt) (not (.getPassenger player)))
      (if (= Material/SAND (-> player .getLocation .clone (.add 0 -1 0) .getBlock .getType))
        (.setCancelled evt true)
        (let [dash-id (rand)]
          (.setWalkSpeed player 0.4)
          (swap! dash-id-table assoc player dash-id)
          (later (sec 4)
            (when (= dash-id (@dash-id-table player))
              #_(helper/smoke-effect (.getLocation player))
              (.setWalkSpeed player 0.6)))))
      (do
        (.setWalkSpeed player 0.2)
        (swap! dash-id-table assoc player nil)))))

; vim: set lispwords+=later :
