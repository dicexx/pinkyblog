# 添付画像

require 'rubyplus'

module PinkyBlog
	class Image
		attr_reader :name, :width, :height, :file_size
	
		def initialize(name, w, h, size)
			@name = name
			@width = w
			@height = h
			@file_size = size
		end
		
		def info
			sprintf("%d×%d / %s", @width, @height, Util.size_to_kb(@file_size))
		end
		
		def etag_base
			"#{@width} #{@height} #{@file_size} "
		end
		
		
	end
end