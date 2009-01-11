#-----------------------------------------------------------
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/pinkyblog/
#-----------------------------------------------------------


$KCODE = 'u'
require 'pathname'

# read config file, and search library dir path
CONFIG_FILE_NAME = './pinkyblog_conf.rb' unless defined?(CONFIG_FILE_NAME)
config_path = Pathname.new(CONFIG_FILE_NAME)
raise "Can't read config file. - #{CONFIG_FILE_NAME}" unless config_path.readable?
mock = Object.new

script = config_path.read.untaint
script.sub!(/^\xef\xbb\xbf/, '') # Deletting UTF-8 BOM

mock.instance_eval(script)
lib_path = Pathname.new(mock.instance_variable_get('@lib_dir_path'))
$LOAD_PATH.unshift(lib_path.to_s.untaint)

require 'rack'
$LOAD_PATH.pop # This path is tainted.(refer to line 6 at rack.rb)
require 'pinkyblog'



# for windows
STDIN.binmode
STDOUT.binmode


# Rack patch
module Rack
	class Response
	
    def set_cookie(key, value)
      case value
      when Hash
        domain  = "; domain="  + value[:domain]    if value[:domain]
        path    = "; path="    + value[:path]      if value[:path]
        # fix (format to httpdate)
        expires = "; expires=" + value[:expires].clone.httpdate if value[:expires]
        secure = "; secure"  if value[:secure]
        value = value[:value]
      end
      value = [value]  unless Array === value
      cookie = Utils.escape(key) + "=" +
        value.map { |v| Utils.escape v }.join("&") +
        "#{domain}#{path}#{expires}#{secure}"

      case self["Set-Cookie"]
      when Array
        self["Set-Cookie"] << cookie
      when String
        self["Set-Cookie"] = [self["Set-Cookie"], cookie]
      when nil
        self["Set-Cookie"] = cookie
      end
    end # def set_cookie
	end # class Response
end # module Rack







class BlogCaller
	def initialize
		conf = PinkyBlog::Config.load(CONFIG_FILE_NAME)
		@pinky_blog_app = PinkyBlog::Application.load(conf)
	end

	def call(env)

		req = PinkyBlog::Request.new(env)
		
		require 'benchmark'
		
		screen = nil; resp = nil
		t1 = Benchmark.realtime{
			screen = @pinky_blog_app.request(req)
		}
		t2 = Benchmark.realtime{
			resp = screen.to_rack_response
		}
		
		
		return resp.to_a
	end
end

