class_name CollisionLayers
extends RefCounted

const WORLD := 1 << 0
const ENEMY := 1 << 1
const PLAYER_ARROW := 1 << 2
const ALLY := 1 << 3
const PLAYER := 1 << 4
const LADDER_HITBOX := 1 << 5
const ENEMY_PROJECTILE := 1 << 6
const TACTICAL_SENSOR := 1 << 7

const ACTOR_MASK := WORLD | ENEMY | ALLY | PLAYER
const PLAYER_ARROW_MASK := WORLD | ENEMY | LADDER_HITBOX

