class Module
	private
	def bool_attr(name, assignable = false)
		attr(name, assignable)
		eval <<-SCRIPT
			def #{name}?
				#{name}
			end
		SCRIPT
		alias_method("#{name}?", name)
	end
	alias battr bool_attr
	
	def bool_attr_reader(*names)
		names.each do |name|
			bool_attr(name, false)
		end
	end
	alias battr_reader bool_attr_reader

	
	def bool_attr_accessor(*names)
		names.each do |name|
			bool_attr(name, true)
		end
	end
	alias battr_accessor bool_attr_accessor

end