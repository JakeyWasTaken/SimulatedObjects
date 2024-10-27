export type Id = string
export type Shapes = "Box" | "Sphere" | "Capsule" | "RoundedFrustum"

-- ------------------------------ Volume Types ------------------------------ --

export type VolumeType = "Wind" | "Force"
export type VolumeWindData = { Type: "Wind", Speed: number }
export type VolumeForceData = { Type: "Force", Force: number }
export type VolumeData = VolumeWindData | VolumeForceData

-- ------------------------------ Object Types ------------------------------ --

export type ObjectData = {
	Object: BasePart | Model,

	MaxAngle: number,
	ApexRadius: number,

	Mass: number?,
	Damping: number?,
	Speed: number?,
	Force: number?,

	Orients: boolean
}

-- ----------------------------- Collider Types ----------------------------- --

export type BoxColliderData = {
	Shape: "Box",
	Center: Attachment,
	Size: Vector3,
	StreamingRadius: number
}

export type SphereColliderData = {
	Shape: "Sphere",
	Center: Attachment,
	Radius: number,
	StreamingRadius: number
}

export type CapsuleColliderData = {
	Shape: "Capsule",
	Start: Attachment,
	End: Attachment,
	Radius: number,
	StreamingRadius: number
}

export type RoundedFrustumColliderData = {
	Shape: "RoundedFrustum",
	Start: Attachment,
	End: Attachment,
	StartRadius: number,
	EndRadius: number,
	StreamingRadius: number
}

export type ColliderData = BoxColliderData | SphereColliderData | CapsuleColliderData | RoundedFrustumColliderData

-- -------------------------------- Streaming ------------------------------- --

-- A streaming relationship job is not a stream job in which objects are actually streamed
-- in or out, it is one where the references between colliders and objects are to be updated
export type StreamRelationshipJobs = { { ColliderId: Id, ObjectIds: { Id } } }

-- Object id pointing to array of collider ids, we do this to reduce function calls when objects release their colliders.
export type BulkObjectStreamRelationshipJobs = { [Id]: { Id } }

export type StreamOutJobs = { [Id]: boolean }
export type StreamInJobs = { [Id]: boolean }

export type StreamingResetJobs = { { Object: BasePart | Model, InitialTransform: CFrame } }

return true
