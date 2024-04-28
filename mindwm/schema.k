schema MindwmUserHost: 
	hostname: str

schema MindwmUser:
	username: str
	hosts: [MindwmUserHost]

schema MindwmContext:
	name: str
	users: [MindwmUser]	
