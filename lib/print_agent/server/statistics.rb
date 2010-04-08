
module PrintAgent
	module Server
		class Statistics
			def initialize
				@v = {:spool => 0, :accept => 0, :reject => 0, :expire => 0, :fail => 0, :notify => 0}
			end

			def inc (s)
				@v[s] = (@v[s] || 0) + 1
			end

			def values
				return @v
			end
		end
	end
end
