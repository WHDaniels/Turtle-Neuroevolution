extensions [ py ]
globals [ network-type energy-loss food-uptimes hazard-uptimes multi fitness ]

turtles-own [
              fitness-error eat-times last-eat weights energy turtle-birth-tick
              ahead ahead-left ahead-right
              left-side right-side
              behind-left behind-right behind
            ]

patches-own [ patch-birth-tick ]

to setup-python-environment

  py:setup "C:\\Users\\mercm\\Desktop\\472 Final Project\\venv\\Scripts\\python"
  py:run "import network as cog"
  py:run "import numpy as np"
  py:run "agents = {}"

end

to setup

  clear-all
  setup-plots
  setup-python-environment

  set multi Network = "Multi-Layer (3 inputs)" or Network = "Multi-Layer (8 inputs)"

  ask patches [ set pcolor blue ]  ; Create sea for turtle agents
  ask patches [
    if food-level / count patches > random-float 1 [ set pcolor green set patch-birth-tick 0 ]
    if hazards? [ if hazard-level / count patches > random-float 1 [ set pcolor red ] ]
  ]

  set food-uptimes (list [])
  set hazard-uptimes (list [])

  create-turtles start-agents [

    setxy random-xcor random-ycor
    set energy 50
    set shape "turtle"
    set turtle-birth-tick 0
    set eat-times (list [])

    py:set "id" who

    initialize-agent-cognition
    copy-agent-weights

  ]

  reset-ticks

end


to go

  set energy-loss initial-energy-loss * (count turtles / 10) ^ 2                        ; The rate at which agents lose energy due to movement

  ask turtles [

    if energy < 0 or (ticks - random-normal turtle-birth-tick 100) > age-limit [ die ]  ; Agent dies if they are exhausted or too old
    eat
    reproduce
    perceive
    move

  ]

  regulate-environment

  plot-fitness

  tick

end

to eat

  if [pcolor] of patch-here = green     ; If an agent is on a food patch
  [

    handle-fitness-values
    ask patch-here [ set pcolor blue ]  ; Remove the food patch
    set energy energy + 10              ; increase energy of the agent by 10
  ]

  if [pcolor] of patch-here = red
  [

    ; Update the hazard uptimes list
    set hazard-uptimes lput (ticks - [ patch-birth-tick ] of patch-here) hazard-uptimes
    if ticks > fitness-plot-interval [ set hazard-uptimes remove-item 0 hazard-uptimes ]

    ask patch-here [ set pcolor blue ]  ; Remove the hazard patch
    set energy energy - 10              ; decrease energy of the agent by 10

  ]

end

to reproduce

  if energy > 100 [               ; If the agent has a surplus of energy

    set energy energy - 50
    hatch-agent                   ; Hatch an offspring agent by using half of the current agent's energy

  ]

end

to hatch-agent

  hatch 1 [

    set turtle-birth-tick ticks                                                       ; Set the current tick to the birth tick of the agent(s)

    py:set "id" who
    py:set "parent_id" [who] of myself                                                ; Keep track of the parent's agent ID

    initialize-agent-cognition

    py:run "agents[id].input.weight = agents[parent_id].input.weight"                 ; The offspring agent(s) has the same network weights as its parent
    if multi [ py:run "agents[id].hidden.weight = agents[parent_id].hidden.weight" ]  ; If mutli-layer cognition, set the hidden layer as well

    copy-agent-weights

    ; Make alterations to the offspring agent's network weights based on the mutation rate [network.py -> mutate() for details]
    py:set "mutation_rate" mutation-rate
    ifelse multi
    [ py:run "agents[id], mutated = cog.mutate(agents[id], mutation_rate, multi_layer=True)" ]
    [ py:run "agents[id], mutated = cog.mutate(agents[id], mutation_rate)" ]

    if py:runresult "mutated" [ set color random 140 ]

    setxy random-xcor random-ycor ; Spawn agent randomly in the world to avoid direct competition with the parent

  ]

end

to move

  if ticks mod move-interval = 0 [                                ; All agents move at some tick interval

    py:set "id" who
    get-inputs-based-on-network                                   ; Give perception inputs to python
    let points py:runresult "cog.get_action(agents[id], inputs)"  ; Get the agents next action from perception inputs
    let action position max points points                         ; The largest of the outputs (from softmax) is the next action

    (ifelse                                                       ; A maximized index 0 corresponds to not turning
      action = 1 [ lt 20 ]                                        ; A maximized index 1 corresponds to taking a slight left turn
      action = 2 [ rt 20 ]                                        ; A maximized index 2 corresponds to taking a slight right turn
    )

  ]

  fd 0.2
  set energy energy - energy-loss                                 ; Movement causes energy loss by the parameterized amount

end

to get-inputs-based-on-network

  if Network = "Single-Layer (3 inputs)" or Network = "Multi-Layer (3 inputs)"    ; Give python front facing perception inputs
  [ py:set "inputs" (list ahead ahead-left ahead-right) ]

  if Network = "Single-Layer (8 inputs)" or Network = "Multi-Layer (8 inputs)" [  ; Give python total preception inputs
    py:set "inputs" (list
      ahead ahead-left ahead-right
      left-side right-side
      behind-left behind-right behind)
  ]

end

to perceive

  set ahead get-percept 0                   ; Agent preceives patches in a cone in front of itself.
  set ahead-left get-percept -45            ;                                ...in front of itself to the left.
  set ahead-right get-percept 45            ;                                ...in front of itself to the right.

  if Network = "Single-Layer (8 inputs)"
  or Network = "Multi-Layer (8 inputs)"
  [

    set left-side get-percept -90           ;                                ...to its left side.
    set right-side get-percept 90           ;                                ...to its right side.


    set behind-left get-percept -135        ;                                ...behind itself to its left.
    set behind-right get-percept 135        ;                                ...behind itself to its right.
    set behind get-percept 180              ;                                ...behind itself.

  ]

  ; visualize-agent-vision

end

to regulate-environment

  let num-food count patches with [pcolor = green]                         ; Get the number of food patches in environment
  let num-hazards count patches with [pcolor = red]                        ; Get the number of hazard patches in environment

  if num-food < food-level                                                 ; If food in environment is too scarce
  [ ask one-of patches [ set pcolor green set patch-birth-tick ticks ] ]   ; Add food to the environment

  if hazards? and num-hazards < hazard-level                               ; If hazard in environment is too scarce
  [ ask one-of patches [ set pcolor red set patch-birth-tick ticks ] ]     ; Add hazard to the environment

  ; We can decay or increase patches over time as well:
  ; if ticks mod 5000 = 0 [ set hazard-level hazard-level + 1 ]
  ; if ticks mod 1250 = 0 [ set food-level food-level - 1 ]

end

to handle-fitness-values

  set eat-times lput (ticks - last-eat) eat-times
  set last-eat ticks
  if ticks > fitness-plot-interval [ set eat-times remove-item 0 eat-times ]
  set fitness-error mean eat-times

  set food-uptimes lput (ticks - [ patch-birth-tick ] of patch-here) food-uptimes
  if ticks > fitness-plot-interval [ set food-uptimes remove-item 0 food-uptimes ]

end

to-report report-fitness

  ifelse length food-uptimes > 0 and length hazard-uptimes > 0 and length [fitness-error] of turtles > 0 [
    report ((- (median food-uptimes * 0.9 + mean food-uptimes * 0.1) * 5 +
      (median hazard-uptimes * 0.9 + mean hazard-uptimes * 0.1) -
      (median [fitness-error] of turtles * 0.9 + mean [fitness-error] of turtles * 0.1)) / sqrt count turtles)
  ] [ report -12345 ]

end


to plot-fitness

  if ticks > fitness-plot-interval and ticks mod fitness-plot-interval = 0 and count turtles > 0 [
    set-current-plot "Fitness Error (Eat Interval)"
    let weighted-fitness-error median [fitness-error] of turtles * 0.9 + mean [fitness-error] of turtles * 0.1
    set-current-plot-pen "default" plot weighted-fitness-error

    set-current-plot "Fitness Error (Food Uptime)"
    let weighted-food-uptime median food-uptimes * 0.9 + mean food-uptimes * 0.1
    set-current-plot-pen "default" plot weighted-food-uptime

    ifelse hazards? [
      set-current-plot "Hazard Uptimes"
      let weighted-hazard-uptime median hazard-uptimes * 0.9 + mean hazard-uptimes * 0.1
      set-current-plot-pen "default" plot weighted-hazard-uptime

      set-current-plot "Fitness"
      set-current-plot-pen "default" plot (- weighted-food-uptime * 5 + weighted-hazard-uptime - weighted-fitness-error) / sqrt count turtles
    ]
    [
      set-current-plot "Fitness"
      set-current-plot-pen "default" plot (- weighted-food-uptime * 5 - weighted-fitness-error) / sqrt count turtles
    ]
  ]


end

to initialize-agent-cognition
  ; Initialize agents with neural network brains
  (ifelse
      Network = "Single-Layer (3 inputs)" [ py:run "agents[id] = cog.SingleLayer()" ]
      Network = "Single-Layer (8 inputs)" [ py:run "agents[id] = cog.SingleLayer(num_inputs=8)" ]
      Network = "Multi-Layer (3 inputs)" [ py:run "agents[id] = cog.MultiLayer()" ]
      Network = "Multi-Layer (8 inputs)" [ py:run "agents[id] = cog.MultiLayer(num_inputs=8, num_hidden=3)" ]
    )
end

to copy-agent-weights

  ifelse Network = "Single-Layer (3 inputs)" or Network = "Single-Layer (8 inputs)"
    [ set weights py:runresult "agents[id].input.weight.detach().numpy()" ]
    [ set weights py:runresult "[agents[id].input.weight.detach().numpy(), agents[id].hidden.weight.detach().numpy()]" ]

end

to-report get-percept [ angle ]

  ; Reporter for agent perception in-cone given a direction
  let percept min-one-of (in-vision-at patches angle) with [pcolor = green or pcolor = red] [ distance myself ]
  (ifelse
    percept = nobody [ report 0 ]
    [pcolor] of percept = green [ report distance percept ]
    [ report (- distance percept) ])

end

to-report in-vision-at [ agentset angle ]

  ; Reporter to determine whether objects are in vision of an agent
  rt angle
  let result agentset in-cone vision-distance (vision-angle / 3)
  lt angle
  report result

end

to visualize-agent-vision

  let in (patch-set (in-vision-at patches -135) (in-vision-at patches 135))
  ask in [ set pcolor red ]
  let not-in patches with [ not member? self in ]
  ask not-in [ set pcolor blue ]

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
1
1
1
ticks
30.0

BUTTON
26
14
89
47
NIL
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
119
14
182
47
NIL
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
20
502
192
535
mutation-rate
mutation-rate
0
100
5.0
1
1
NIL
HORIZONTAL

PLOT
656
27
932
226
Turtles
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
"default" 1.0 0 -16777216 true "" "plot count turtles"

SLIDER
19
389
191
422
vision-angle
vision-angle
0
360
120.0
5
1
NIL
HORIZONTAL

PLOT
656
237
931
435
Variants
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
"default" 1.0 0 -16777216 true "" "plot length remove-duplicates [color] of turtles"

SLIDER
20
427
192
460
vision-distance
vision-distance
0
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
20
465
192
498
age-limit
age-limit
500
5000
2500.0
500
1
NIL
HORIZONTAL

SLIDER
20
169
193
202
food-level
food-level
1
100
88.0
1
1
NIL
HORIZONTAL

SLIDER
20
317
193
350
move-interval
move-interval
1
10
1.0
1
1
NIL
HORIZONTAL

TEXTBOX
52
367
159
386
Stable Parameters
13
0.0
1

TEXTBOX
45
58
170
92
Dynamic Parameters
13
0.0
1

SLIDER
20
205
193
238
initial-energy-loss
initial-energy-loss
0
0.5
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
19
130
192
163
start-agents
start-agents
1
50
20.0
1
1
NIL
HORIZONTAL

CHOOSER
17
81
193
126
Network
Network
"Single-Layer (3 inputs)" "Single-Layer (8 inputs)" "Multi-Layer (3 inputs)" "Multi-Layer (8 inputs)"
2

PLOT
940
13
1144
153
Fitness Error (Eat Interval)
k-ticks
Fitness Score
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
1296
410
1468
443
fitness-plot-interval
fitness-plot-interval
0
1000
250.0
250
1
NIL
HORIZONTAL

PLOT
940
158
1143
298
Fitness Error (Food Uptime)
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
"default" 1.0 0 -16777216 true "" ""

SWITCH
53
244
158
277
hazards?
hazards?
0
1
-1000

SLIDER
20
280
192
313
hazard-level
hazard-level
0
100
6.0
1
1
NIL
HORIZONTAL

PLOT
1151
42
1593
402
Fitness
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
"default" 1.0 0 -16777216 true "" ""

PLOT
940
302
1143
442
Hazard Uptimes
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
"default" 1.0 0 -16777216 true "" ""

@#$#@#$#@
## WHAT IS IT?

This model is meant as a demonstration of adaptive agent cognition in the context of neuro-evolution by natural selection.

The cognitive backend for the agents is one of a few neural networks that can be selected. The first two are single-layer neural networks. The first having 3 perception inputs and the second having 8 (the former having front-facing perception and the latter having 360 degree perception.)

This model explores the effects of different structures of neural agents on fitness values in a competitive environment with similar agents.


## HOW IT WORKS

Agents are spawned into the environment and initialized with random neural network weights. If they run out of energy or become too old, they die. If they are on a food patch, they eat it and gain energy. If their energy is above 100, they reproduce and hatch an offspring agent that has a chance to mutate (one or more of its network weights) based on the 'mutation-rate' parameter. The agent gathers information from the nearby environment through patch perception and moves based on the output of its neural network brain given the perception inputs.

The environment is regulated to keep spawning food at a constant and at controlled intervals.


## HOW TO USE IT

To get the best chance at evolving competent agents, select the most complex multi-layer cognition and coax agents into learning from very slight changes to the world.

For example, this may entail setting food-level to the max and hazard-level to the least and very slowly increasing the hazard-level and decreasing the food-level to force learning/adaption.

If one would rather observe quick learning, a simpler cogntion can be used (3-input Single Layer) and set parameters to some competitive values (such as a food-level of 30 and a hazard-level of 1).

Simple agents learn fast, but are very stubborn to adapt to very complex envrionments.
Complex agents learn slowly, but can explore the potential fitness space much better.

## THINGS TO NOTICE

Emergent behavior that comes either in the form of better agent fitness, better "human" looking movement, or the rare "follow the leader" behavior (usually indicative of population collapse).

Given agent genes (network weights) become homogenous enough, agents can seem to be following “leaders” or creating pathways that other agents follow even though they actually have no perception of other agents at all.


## THINGS TO TRY

Gradually changing parameters. Careful! As sudden or drastic changes in the environment do not allow for agents to adapt!

## EXTENDING THE MODEL

A structural neuroevolution where the cognition structure itself can be adaptive is a good idea for an extension of this model. 

Given that the bane of learning/adapting is immutable frameworks and given the static nature of the neural network structures used here, the next steps may be to allow the learning process to take advantage of network capacity also.

## NETLOGO FEATURES

This model uses the py extension to allow NetLogo to access the PyTorch Python module, allowing for use of neural networks created with Torch.

## RELATED MODELS

  * Gurkan, C., Head, B., Woods, P. and Wilensky, U. (2018). NetLogo Vision Evolution model. http://ccl.northwestern.edu/netlogo/models/VisionEvolution. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

  * Dabholkar, S. and Wilensky, U. (2016). NetLogo GenEvo 3 Genetic Drift and Natural Selection model. http://ccl.northwestern.edu/netlogo/models/GenEvo3GeneticDriftandNaturalSelection. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.



## CREDITS AND REFERENCES

William Daniels
CS 472 - Final Project
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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Fitness Runs" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 10 [go]</go>
    <timeLimit steps="100000"/>
    <exitCondition>not any? turtles</exitCondition>
    <metric>report-fitness</metric>
    <enumeratedValueSet variable="vision-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fitness-plot-interval">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hazards?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hazard-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network">
      <value value="&quot;Multi-Layer (3 inputs)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-agents">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-interval">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-limit">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision-angle">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation-rate">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-level">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-energy-loss">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
