#!/usr/local/bin/ruby
#
#-----------------------------------------------------------
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/
#-----------------------------------------------------------

begin

	$SAFE = 1
	require 'blog'

	app = Rack::Builder.new{
		run BlogCaller.new
	}
	

	Rack::Handler::CGI.run(app)

	
rescue Exception

	require 'cgi'
	cgi = CGI.new
	opts = {}
	opts['type'] = 'text/plain'
	opts['status'] = '500 Internal Server Error'
	
	body = ''
	body << "#{$!} (#{$!.class})\n"
	body << "  " << $@.join("\n  ") << "\n\n"
	body << "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]" << "\n"
	if defined?(PinkyBlog::CORE_VERSION) then
		body << "Pinky:blog #{PinkyBlog::CORE_VERSION}"
	else
		body << "Pinky:blog (system version is unidentified)"
	end
	cgi.out(opts){ body }
end

