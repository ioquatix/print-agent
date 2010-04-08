
module PrintAgent
	
	module Server
		# Job Status
		OKAY = 0
		UNKNOWN = -1
		ACCEPTED = 1

		REJECTED = 10
		DUPLICATE = 12
		MISSING = 13
		PENDING = 14

		# XMLRPC Keys
		STATUS = "STATUS"
		DETAILS = "DETAILS"
		PRINTER = "PRINTER"
	end
	
end