#-----------------------------------------------------------
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/
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
        value = value[:value]
      end
      value = [value]  unless Array === value
      cookie = Utils.escape(key) + "=" +
        value.map { |v| Utils.escape v }.join("&") +
        "#{domain}#{path}#{expires}"

      case self["Set-Cookie"]
      when Array
        self["Set-Cookie"] << cookie
      when String
        self["Set-Cookie"] = [self["Set-Cookie"], cookie]
      when nil
        self["Set-Cookie"] = cookie
      end
    end
	end

	module Handler
		class WEBrick

      def service(req, res)
        env = req.meta_vars
        env.delete_if { |k, v| v.nil? }

        env.update({"rack.version" => [0,1],
                     "rack.input" => StringIO.new(req.body.to_s),
                     "rack.errors" => STDERR,

                     "rack.multithread" => true,
                     "rack.multiprocess" => false,
                     "rack.run_once" => false,

                     "rack.url_scheme" => ["yes", "on", "1"].include?(ENV["HTTPS"]) ? "https" : "http"
                   })

        env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
        env["QUERY_STRING"] ||= ""
        env["REQUEST_PATH"] ||= "/"
        env.delete "PATH_INFO"  if env["PATH_INFO"] == ""

        status, headers, body = @app.call(env)
        begin
          res.status = status.to_i
          headers.each { |k, vs|
						# fix for multiple cookies
						# refer to: http://d.hatena.ne.jp/repeatedly/20080925/1222347465
					  if k == 'Set-Cookie'
					    vs.each { |cookie|
					      res.cookies << cookie
					    }
					  else
					    vs.each { |v|
					      res[k] = v
					    }
					  end
          }
					
          body.each { |part|
            res.body << part
          }
        ensure
          body.close  if body.respond_to? :close
        end
      end
		end
	end
end







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

