module Enumerable
	def total
		inject{|t, inc| t + inc }
	end
end
