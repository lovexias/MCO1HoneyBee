breed [hives hive]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Honey Bee System Model
; Each tick = 1 day; bee lifespan = 7 weeks (49 days)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ------------------------------
;; GLOBAL VARIABLES
;; ------------------------------
globals [
  temperature         ;; current environmental temperature
  hive-resources      ;; total nectar resources stored in the hive
  pollination-success ;; count of flowers successfully pollinated
  crop-yield          ;; cumulative number of crops that matured and yielded produce
]

;; ------------------------------
;; BREEDS (Turtle Types)
;; ------------------------------
breed [bees bee]       ;; honey bee agents
breed [flowers flower] ;; flower patches that produce nectar
breed [crops crop]     ;; crop plants dependent on pollination

;; ------------------------------
;; FLOWER VARIABLES
;; ------------------------------
flowers-own [
  nectar      ;; amount of nectar available to collect
  pollinated? ;; flag: has this flower been visited/pollinated by a bee?
]

;; ------------------------------
;; CROP VARIABLES
;; ------------------------------
crops-own [
  pollinated? ;; flag: has crop been pollinated?
  growth      ;; growth progress towards yielding (e.g., fruit)
]

;; ------------------------------
;; BEE VARIABLES
;; ------------------------------

;; ------------------------------
;; HIVE VARIABLES
;; ------------------------------
hives-own [
  stores            ;; nectar stored in this hive
]

bees-own [
  carrying-nectar   ;; amount of nectar currently carried back to hive
  age               ;; age in days (ticks)
  full?             ;; flag: is this bee "full" and ready to return?
  days-since-food   ;; days since last nectar collection

  home-hive         ;; the hive turtle this bee returns to
]

;; ------------------------------
;; SETUP PROCEDURE
;; Initializes world, shapes, globals, and initial agents
;; ------------------------------
to setup
  clear-all                               ;; clear all turtles, patches, and monitors

  ;; set turtle shapes for easy visualization
  set-default-shape bees "bug"
  set-default-shape flowers "circle"
  set-default-shape crops "square"
  set-default-shape hives "house"

  ;; initialize all global counters/trackers
  set hive-resources 0                    ;; no stored nectar at start
  set pollination-success 0
  set crop-yield 0
  set temperature initial-temperature     ;; start at slider-defined temperature
  set starvation-threshold starvation-threshold

  ;; create environment
  setup-flowers                           ;; seed flower patches
  setup-crops                             ;; seed crop patches

  ;; --- create hives ---
  create-hives initial-hives [
    setxy random-xcor random-ycor
    set color brown
    set size 2
    set stores 0
  ]

  ;; create initial bees
  create-bees initial-bees [
    setxy random-xcor random-ycor         ;; place randomly
    set home-hive nobody                  ;; initialize as nobody (avoid 0 → move-to error)
    set carrying-nectar 0                 ;; empty nectar load
    set age 0                             ;; start life timer
    set days-since-food 0                 ;; just fed
    set full? false                       ;; not yet ready to return
    set color yellow                      ;; bees appear yellow
    ;; assign a persistent home hive (nearest); if none, leave as nobody
    if any? hives [
      let me self
      set home-hive min-one-of hives [ distance me ]
    ]
  ]

  reset-ticks                             ;; start the tick counter at 0
end

;; ------------------------------
;; Flower Initialization
;; Creates patches with flowers and sets initial nectar
;; ------------------------------
to setup-flowers
  ask n-of initial-flowers patches [
    sprout-flowers 1 [
      set nectar random 5 + 5             ;; random nectar amount 5–9
      set pollinated? false               ;; no visits yet
      set color orange                    ;; orange indicates nectar presence
    ]
  ]
end

;; ------------------------------
;; Crop Initialization
;; Creates patches with crops and sets growth state
;; ------------------------------
to setup-crops
  ask n-of initial-crops patches with [not any? turtles-here] [
    sprout-crops 1 [
      set pollinated? false               ;; not pollinated yet
      set growth 0                        ;; initial growth stage
      set color green                     ;; green indicates crop
    ]
  ]
end

;; ------------------------------
;; MAIN LOOP
;; One tick of simulation: update environment and agents
;; ------------------------------
to go
  update-temperature                      ;; environmental fluctuation

  ;; each bee moves, forages, and ages
  ask bees [
    move
    forage
    age-bee
  ]

  ;; bees that are "full" return nectar to hive
  ask bees with [full?] [ return-to-hive ]

  regenerate-flowers                      ;; flowers rebuild nectar after pollination
  recolor-flowers                         ;; adjust visual color based on nectar/pollination
  grow-crops                              ;; crops progress toward yield and die when done
  reproduce-bees                          ;; spawn new bees if hive-resources sufficient
  update-pollination-metrics              ;; recalculate global pollination-success
  tick
end

;; ------------------------------
;; ENVIRONMENTAL UPDATE
;; Temperature random walk
;; ------------------------------
to update-temperature
  ;; adjust temperature by ±0.25 per day (tick)
  set temperature temperature + (random-float 0.5 - 0.25)
end

;; ------------------------------
;; BEE MOVEMENT
;; Random walk
;; ------------------------------
to move
  if full? [ stop ]                        ;; if carrying nectar, don’t forage
  ifelse any? flowers [                    ;; are there flowers anywhere?
    let nearest min-one-of flowers [distance myself]
    face nearest                           ;; turn toward that flower
    fd 1                                   ;; step one patch closer
  ] [
    ;; fallback to a bit of random wandering
    rt (random 50) - (random 50)
    fd 1
  ]
end

;; ------------------------------
;; FORAGING BEHAVIOR
;; Bees search for flowers and attempt pollination
;; ------------------------------
to forage
  if full? [ stop ]
  ;; 1) Prefer flowers for nectar
  let flower-target one-of flowers-here
  ifelse flower-target != nobody [
    pollinate flower-target
    collect-nectar flower-target
  ] [
    ;; 2) If no flower here, try pollinating a crop
    let crop-target one-of crops-here
    if crop-target != nobody [
      pollinate crop-target
    ]
  ]
end

;; ------------------------------
;; POLLINATION
;; Mark flower/crop as pollinated and change color
;; ------------------------------
to pollinate [target]
  if not [pollinated?] of target [        ;; only first visit counts
    ask target [
      set pollinated? true                ;; flag as pollinated
      set color pink                      ;; visual feedback
      if breed = crops [                  ;; if it's a crop, increase its growth
        set growth growth + 1
      ]
    ]
  ]
end

;; ------------------------------
;; FLOWER RECOLORING
;; Visual cue: orange scaled by nectar, pink if pollinated
;; ------------------------------
to recolor-flowers
  ask flowers [
    ifelse pollinated? [
      set color pink                      ;; fully pollinated
    ] [
      ;; show nectar level from light→dark orange
      set color scale-color orange nectar 0 10
    ]
  ]
end

;; ------------------------------
;; NECTAR COLLECTION
;; Bees pick up nectar and mark full?
;; ------------------------------
to collect-nectar [target]
  let nectar-available [nectar] of target
  if nectar-available > 0 [
    let collected min list nectar-available 3    ;; carry up to 3 units per day
    ask target [ set nectar nectar - collected ]
    set carrying-nectar carrying-nectar + collected
    if collected > 0 [ set days-since-food 0 ]   ;; reset starvation counter
    if carrying-nectar >= 10 [ set full? true ]  ;; threshold to return
  ]
end

;; ------------------------------
;; RETURN TO HIVE
;; Deposit nectar and reset bee state
;; ------------------------------
to return-to-hive
  ;; ensure bee has a valid home hive
  if not any? hives [ stop ]                      ;; no hives → nothing to do
  if not is-turtle? home-hive [                   ;; unassigned (0) or nobody
    let me self
    set home-hive min-one-of hives [ distance me ]
  ]
  if not is-turtle? home-hive [ stop ]            ;; still invalid → bail

  ;; move, deposit, reset
  let deposit carrying-nectar
  move-to home-hive
  ask home-hive [ set stores stores + deposit ]
  set hive-resources hive-resources + deposit
  set carrying-nectar 0
  set days-since-food 0
  set full? false
end

;; ------------------------------
;; FLOWER REGENERATION
;; Refill nectar over time if pollinated
;; ------------------------------
to regenerate-flowers
  ask flowers [
    if pollinated? and nectar < 10 and temperature >= 15 and temperature <= 30 [
      set nectar nectar + 1               ;; regen one unit per tick under good temps
    ]
  ]
end

;; ------------------------------
;; CROP GROWTH & YIELD
;; Crops grow after pollination and die when yielding
;; ------------------------------
to grow-crops
  ask crops [
    if pollinated? and growth < 5 [ set growth growth + 0.1 ] ;; gradual growth
    if growth >= 5 [
      set crop-yield crop-yield + 1      ;; record a yield event
      die                                ;; remove the harvested crop
    ]
  ]
end

;; ------------------------------
;; BEE REPRODUCTION
;; Spawn new bees using hive resources
;; ------------------------------
to reproduce-bees
  if hive-resources >= 20 [               ;; require 20 units to reproduce
    create-bees 20 [                      ;; produce 20 new bees
      setxy random-xcor random-ycor
      set home-hive nobody                ;; initialize (avoid 0)
      set carrying-nectar 0
      set age 0
      set days-since-food 0
      set full? false
      set color yellow
      if any? hives [
        let me self
        set home-hive min-one-of hives [ distance me ]
        ;; move-to home-hive              ;; optional: start newborns at hive
      ]
    ]
    set hive-resources hive-resources - 20 ;; deduct resource cost
  ]
end

;; ------------------------------
;; AGING & DEATH
;; Bees die of old age (49 days) or extreme temperature
;; ------------------------------
to age-bee
  set age age + 1                          ;; age by one day
  set days-since-food days-since-food + 1  ;; hunger increases by one day
  if age > 49                              ;; die after 49 days
     or temperature < 10                   ;; or if too cold
     or temperature > 35                   ;; or if too hot
     or days-since-food > starvation-threshold [ ;; or if starved
    die
  ]
end

;; ------------------------------
;; METRICS UPDATE
;; Track total pollination successes
;; ------------------------------
to update-pollination-metrics
  set pollination-success count flowers with [pollinated?]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
719
58
783
91
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
719
109
782
142
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
721
157
893
190
initial-bees
initial-bees
1
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
722
215
894
248
initial-flowers
initial-flowers
0
200
75.0
1
1
NIL
HORIZONTAL

SLIDER
724
278
896
311
initial-crops
initial-crops
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
724
339
896
372
initial-temperature
initial-temperature
0
40
25.0
1
1
NIL
HORIZONTAL

MONITOR
911
157
968
202
Bees
count bees
17
1
11

MONITOR
911
217
1009
262
NIL
hive-resources
17
1
11

MONITOR
911
281
1027
326
NIL
pollination-success
17
1
11

MONITOR
912
342
979
387
NIL
crop-yield
17
1
11

MONITOR
994
341
1076
386
NIL
temperature
17
1
11

PLOT
208
496
408
646
Bee Population
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"bees" 1.0 0 -1184463 true "" "plot count bees"

PLOT
425
498
625
648
Average Nectar
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"nectar" 1.0 0 -955883 true "" "plot mean [nectar] of flowers"

PLOT
641
499
841
649
Pollination Success
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"success" 1.0 0 -2064490 true "" "plot pollination-success"

SLIDER
724
395
896
428
starvation-threshold
starvation-threshold
1
20
14.0
1
1
NIL
HORIZONTAL

PLOT
854
501
1054
651
Crop Yield
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"yield" 1.0 0 -10899396 true "" "plot crop-yield"

SLIDER
722
454
898
487
initial-hives
initial-hives
1
10
5.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
