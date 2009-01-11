#-----------------------------------------------------------
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/pinkyblog/
#-----------------------------------------------------------


	require 'blog'
	require 'webrick'
	require 'amrita/xml'
	
	conf = PinkyBlog::Config.load(CONFIG_FILE_NAME)

	app = Rack::Builder.new{
		use Rack::Static, :urls => conf.http_server_static_urls
		run BlogCaller.new
	}
	
	if ARGV.include?('--testrun') or $LOADED_FEATURES.include?('exerb/mkexy.rb') then
		# for exerb compiling
		puts "blog_server.rb : test run"
		
		BlogCaller.new.call({'rack.input' => StringIO.new, 'rack.url_scheme' => 'http', 'HTTP_HOST' => 'localhost'})
	else
		# standard boot
		Rack::Handler::WEBrick.run(app, {:Port => conf.http_server_port})
	end
	

	

	
