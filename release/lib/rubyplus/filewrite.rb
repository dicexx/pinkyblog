# RubyPlus 0.2 later

class File
	def self.write(filename, str, mode = 'w')
		open(filename, mode){|f|
			f.write str
		}
	end

	def self.puts(filename, obj, mode = 'w')
		open(filename, mode){|f|
			f.puts obj
		}
	end

end
