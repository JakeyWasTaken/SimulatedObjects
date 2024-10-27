return {
	-- Radius around the camera in which events take place, i.e active colliders, volumes
	CAMERA_ACTIVE_RADIUS = 250,
	-- Radius around the camera in which wind effects objects, at small values there will be noticeable jumps when objects start to react to wind
	WIND_ACTIVE_RADIUS = 100,
	-- Radius around the camera at which we start to throttle objects
	THROTTLING_START_RADIUS = 50,
	-- Throttled rate at which objects should be updated at
	THROTTLED_OBJECT_UPDATE_RATE = 1 / 10,
	-- Target rate at which objects should be updated at
	OBJECT_UPDATE_RATE = 1 / 60,
	-- The lower this number the more optimized wind is but the less random it looks
	SEED_WRAP = 5,
}
