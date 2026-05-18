extends ObjectState

# Intentionally empty. OrbFire is a follower projectile spawned by Orb
# while on_fire is true — Orb drives its position via OrbFire.tick (which
# snaps to creator) and decides when to disable it, so this state has no
# per-tick logic of its own. Configure the Hitbox child in the scene file
# to tune fire damage / size / etc.
