require 'pathname'

class Object
	def to_pathname
		Pathname.new(self)
	end
end

class Pathname
	def to_pathname
		self
	end
end


module Kernel
  def Path(path_str)
    Pathname.new(path_str)
  end
	alias Pathname Path
  module_function :Path
  module_function :Pathname

end
