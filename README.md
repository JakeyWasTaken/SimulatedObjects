# SimulatedObjects

### [Follow my work here](https://discord.gg/5h4XtFXT4g)

### WARNING: !! THIS IS NOT PRODUCTION READY !!

### NOTE: THIS IS NOT SOMETHING I PLAN TO MAINTAIN OR UPDATE, USE WITH THE EXPECTATION OF ISSUES. THIS PROJECT ALSO TAKES ADVANTAGE OF THE NEW VECTOR LIB, IF YOU USE THIS OUTSIDE OF THE ROBLOX IDE THEN YOU WILL HAVE TO ADD THESE TYPES IN A DEFINITION FILE TO YOUR LSP

```luau
declare class vector extends Vector3
    Magnitude: number
    Unit: Vector3
    X: number
    Y: number
    Z: number
    function Abs(self): Vector3
    function Angle(self, other: Vector3, axis: Vector3?): number
    function Ceil(self): Vector3
    function Cross(self, other: Vector3): Vector3
    function Dot(self, other: Vector3): number
    function Floor(self): Vector3
    function FuzzyEq(self, other: Vector3, epsilon: number): boolean
    function Lerp(self, goal: Vector3, alpha: number): Vector3
    function Max(self, ...: (Vector3)): Vector3
    function Min(self, ...: (Vector3)): Vector3
    function Sign(self): Vector3
    function __add(self, other: Vector3): Vector3
    function __div(self, other: Vector3 | number): Vector3
    function __idiv(self, other: Vector3 | number): Vector3
    function __mul(self, other: Vector3 | number): Vector3
    function __sub(self, other: Vector3): Vector3
    function __unm(self): Vector3
end

declare vector: {
    create: (x: number, y: number, z: number) -> vector,
    magnitude: (vec: vector) -> number,
    normalize: (vec: vector) -> vector,
    cross: (vec1: vector, vec2: vector) -> vector,
    dot: (vec1: vector, vec2: vector) -> number,
    angle: (vec1: vector, vec2: vector, axis: vector?) -> number,
    floor: (vec: vector) -> vector,
    ceil: (vec: vector) -> vector,
    abs: (vec: vector) -> vector,
    sign: (vec: vector) -> vector,
    clamp: (vec: vector, min: vector, max: vector) -> vector,
    max: (...vector) -> vector,
    min: (...vector) -> vector,

    zero: vector,
    one: vector,
}
```
## Documentation
The documentation will be sparse, types and the dev script should more or less outline everything you will need.

## Todo
- [x] Faster Streaming
- [x] Faster Octree
- [x] Faster Simulation
- [x] Faster Wind
- [x] Support Multiple Colliders
- [x] Support Models
- [x] Colliders can be removed
- [ ] Double Check Migration to new vector lib
- [ ] Wind Volumes
- [ ] Force Volumes
- [ ] Re-Factor Streaming to manage volumes
- [ ] Move away from spring pool approach
