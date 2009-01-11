$LOAD_PATH << './lib'
require 'test/unit'
require 'pinkyblog'
include PinkyBlog

TC = Test::Unit::TestCase

module RequestTest
	def test_foo
		assert(@foo)
	end
	
	def test_main
		@req
	end
end

class BasicRequestTC < TC
	include RequestTest
	
	def setup
		@req = Request.new('http://scl.littlestar.jp/pinky/blog.cgi')
	end
end

