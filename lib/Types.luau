export type Shapes = "Box" | "Sphere" | "Capsule" | "RoundFrustum"

export type VolumeType = "Wind" | "Force"
export type VolumeWindData = { Type: "Wind", Speed: number }
export type VolumeForceData = { Type: "Force", Force: number }
export type VolumeData = VolumeWindData | VolumeForceData

return true
