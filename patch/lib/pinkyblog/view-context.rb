#-> ViewContext
require 'uri'
require 'pathname'
require 'htmlsplit'

require 'pinkyblog/config'
require 'pinkyblog/module-handler'
require 'pinkyblog/request'

module PinkyBlog
	# ビューコンテキスト（ビューに必要な情報のセット）
	class ViewContext
	
		attr_reader :config, :request, :master_mode
		attr_accessor :snapshot_path, :path_refered_by_menu
		attr_reader :warnings
		
		alias master_mode? master_mode

		def initialize(config, request, master_mode = false, snapshot_path = nil)
			@config = config
			@request = request
			@master_mode = master_mode
			@snapshot_path = Pathname.new(snapshot_path) if snapshot_path
			@path_refered_by_menu = nil
			
			@warnings = []
			
		end
		
		def snapshot_mode?
			(@snapshot_path ? true : false)
		end
		
		
		WDAY_TABLE = %w(日 月 火 水 木 金 土)

		def time2str(time)
			return sprintf("%d年%d月%d日（%s） %d:%02d",
			               time.year, time.month, time.day, WDAY_TABLE[time.wday], time.hour, time.min)
		end

		def date2str(time)
			return sprintf("%d年%d月%d日（%s）",
			               time.year, time.month, time.day, WDAY_TABLE[time.wday])
		end
		
		def time2str_short(time)
			return sprintf("%02d-%02d-%02d %02d:%02d",
			               time.year, time.month, time.day, time.hour, time.min)
		end
		
		def date2str_short(time)
			return sprintf("%02d-%02d-%02d", time.year, time.month, time.day)
		end



		def route_to(path, query = nil, fragment = nil)
			
			Util.normalize_path!(path)
			if snapshot_mode? then
				case path
				when '/'
					to = Pathname.new("index.html")
				when '/entries'
					to = Pathname.new('./files/') + Util.page_number_to_file_name('entries', 1)
				else
					to = Pathname.new("files/#{path}.html")
				end
				
				return to.relative_path_from(@snapshot_path.dirname)
			else
				if path == '/' then
					dest = URI.parse(@request.script_name)
					if dest.path.empty? then
						dest.path = '/'
					end
				else
					dest_path = (@request.script_name + path)
					dest_path.squeeze!('/')
					dest = URI.parse(dest_path)
				end
					
				dest.query = query
				dest.fragment = fragment
				
				return dest
			end
		end
		alias uri_to route_to
		
		
		def absolute_uri_to(path, query = nil, fragment = nil)
			Util.normalize_path!(path)
			if @config.use_path_info then
				dest = URI.parse(@request.url)
				
				if path == '/' then
					destp = @request.script_name
				else
					destp = (@request.script_name + path)
				end
				destp.squeeze!('/')
				dest.path = destp
				
				dest.query = query
				dest.fragment = fragment
				return dest
			else
				re = script_uri.dup
				re.path = path
				re.query = (query ? "#{query}&path_info=#{path}" : "path_info=#{path}")
				re.fragment = fragment
				
				re
			end
		end

		def file_route_to(dest_path)
			if snapshot_mode? then
				return Pathname.new(dest_path.to_s).relative_path_from(@snapshot_path)
			else
				dest = script_uri + dest_path.to_s
				return URI(@request.url).route_to(dest)
			end
			
			
		end
		alias file_uri_to file_route_to
		
		def script_uri
			@script_uri ||= URI::HTTP.build({:host => @request.host, :port => @request.port, :path => @request.script_name})
		end

		
		
		
		def get_feed_url(file_name)
			url = script_uri
			url += (config.feed_dir_path + file_name).to_s
			return url
		end
		
		
		
		def self_url
			url = @request.script_url.dup
			if @config.use_path_info? then
				url.path += @request.path_info
			end
			url.query = @request.query
			return url

		end
		
		def etag_base
			"#{CORE_VERSION} #{@request.script_name} #{@config.etag_base} #{@master_mode ? '1' : '0'}"
		end
		
		def current_menu_item
			@config.menu.get_current_item(self)
		end
		
		def current_caption_on_menu
			if (item = current_menu_item) then
				item.caption
			else
				'?'
			end
		end
		
		def on_top_page?
			@request.normalized_path == '/'
		end
		
		def cookie_path
			if @request.script_name.empty? then
				'/'
			else
				@request.script_name
			end
		end



		# HTMLをパースして、属性の置換などを行う
		def parse_html(html)
			doc = HTMLSplit.new(html).document

			scheme_pattern = /\Aex\:(.+?)\:(.+)\Z/

			url_keys = %W(href src action cite data archive codebase background classid longdesk usemap)

			doc.each do |elem|
				if elem.is_a?(StartTag) || elem.is_a?(EmptyElementTag) then
					url_keys.each do |key|
						case elem[key]
						when scheme_pattern
							scheme = $1
							us_target = $2
							target = Util.encode_url($2)
							
							case scheme
							when 'google'
								elem[key] = "http://www.google.com/search?ie=utf-8&q=#{target}"
							when 'wikipedia'
								elem[key] = "http://ja.wikipedia.org/wiki/#{target}"
							when 'tag'
								tags = us_target.split(/[ ]|　/)
								q = tags.map{|x| "tags=#{Util.encode_base64url(x)}"}.join("&")
								elem[key] = route_to("entries", q).to_s
							when 'res'
								if snapshot_mode? then
									to = Pathname.new('files/res') + us_target
									elem[key] = to.relative_path_from(@snapshot_path.dirname).to_s
								else
									elem[key] = file_route_to(@config.res_dir_path + us_target).to_s
								end
							when 'entry'
								elem[key] = route_to("entries/#{target}").to_s
							end
						end
					end
					
						
				end
				
				
			end
			
			return doc.to_s
		end

		
	end
end
