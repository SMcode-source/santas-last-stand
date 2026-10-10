class_name PhysicsLayers
extends RefCounted
## The collision layers every level shares, as bit masks.

## Ground, walls, platforms, props: everything solid.
const WORLD := 1
## Santa on foot.
const PLAYER := 2
## Areas that can be hit (snowmen, enemies). Their owner has take_hit(hit).
const HURTBOX := 4
## The sleigh.
const SLEIGH := 8
## Invisible walls that keep Santa in the playable area but let the sleigh pass.
const WALKER_BOUNDS := 16
