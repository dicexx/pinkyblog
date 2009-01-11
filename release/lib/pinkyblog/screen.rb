#-> Screen, Repository
require 'amrita/template'
require 'digest/md5'
require 'pathname'
require 'time'

require 'pinkyblog/const'
require 'pinkyblog/util'
require 'pinkyblog/menu'
require 'pinkyblog/section'
require 'pinkyblog/view-context'
require 'pinkyblog/option-check'

module PinkyBlog
	class Response
		self.extend OptionCheck
		attr_reader :context, :options
		

		def initialize(context, option_args = {})
			@context = context
			# OptionCheck
			self.class.assert_fulfill_requirement(option_args)
			self.class.set_defaults(option_args)
			
			
			@options = option_args
			option_args.each_pair do |key, value|
				instance_variable_set("@#{key}", value)
			end
		end

		def config
			@context.config
		end
		
		def request
			@context.request
		end
		
		def master_mode?
			@context.master_mode?
		end
		
		def snapshot_mode?
			@context.snapshot_mode?
		end

		private
		def set_message_eating_cookie(rack_response)
			rack_response.set_cookie('message', {:value => '', :path => @context.cookie_path, :expires => Time.now - 100})
		end
	end

=begin
	class SectionResponse < Response
		def to_rack_response
			header = {'Content-Type' => 'text/html'}
			base_screen = PinkyBlog.module_eval(@options[:screen_class].to_s).new(context, @options)
			
			body = base_screen.to_s
			doc = HTMLSplit.new(body).document

			doc.each do |elem|
				case elem
				when StartTag, EmptyElementTag, EndTag
					if elem.name =~ /^h([2-5])$/ then
						elem.instance_variable_set('@name', "h#{$1.to_i + 1}") # あまり美しいやり方ではない
					end
				end
				
				
			end
			
			Rack::Response.new(doc.to_s, HTTP_OK, header)
		end
	end
=end

	# ブラウザに表示する画面をあらわす抽象クラス
	class Screen < Response
		include Amrita::ExpandByMember
		default_opt(:custom_html, {})

		
		
		def gen_sect(cls, opts = {})
			return cls.new(@context, opts)
		end
		
		
		def menu
			config.menu.to_model(@context)
		end
		
		def site_title
			config.site_title
		end
		
		def br
			" "
		end
		
		def pan
			items = []
			
			
			data = pan_data
			data.last[0] = nil
			data.each do |path, caption|
				items << (path ? %Q|<a href="#{@context.route_to(path)}">#{Util.escape_html(caption)}</a>| : Util.escape_html(caption))
				items << "\n"
			end
			
			if config.home_url then
				items.unshift("\n")
				items.unshift(%Q|<a href="#{Util.escape_html(config.home_url)}">home</a>|)
			end
			
			return {:items => items.map{|x| Amrita::SanitizedString.new(x.to_s)}}
		end
		
		def pan_data
			data = []
			
			data << ['/', config.site_title]
			
			return data
		end
		
		
		def body_class
			(master_mode? ? 'for-master' : 'for-guest')
		end
		
		def up_href
			data = pan_data
			if data.size >= 2 then
				return @context.route_to(data[-2][0])
			end
		
		end
		
		def base_css_link
			if snapshot_mode? then
				path = Pathname.new('files/res/pinkyblog/base.css')
				Amrita.a({:href => path.relative_path_from(@context.snapshot_path.dirname).to_s})
			else
			

				uri = @context.file_route_to(config.res_dir_path + 'pinkyblog/base.css')
				Amrita.a({:href => uri})
			end
		end

		
		def cdp_link
			if snapshot_mode? then
				path = Pathname.new('files/csstemplate/style.css')
				Amrita.a({:href => path.relative_path_from(@context.snapshot_path.dirname).to_s})

			else
				if request.cookies['cdp_name'] then
					file_path = config.cdp_dir_path + request.cookies['cdp_name'].slice(/[a-zA-Z0-9_-]+/) + 'csstemplate/style.css'
				else
	 				file_path = config.cdp_dir_path + 'style.css'
				end
				uri = @context.file_route_to(file_path)
				Amrita.a({:href => uri})
				
			end
		end
		
		def print_cdp_link
			if snapshot_mode? then
				path = Pathname.new('files/res/pinkyblog/print.css')
				Amrita.a({:href => path.relative_path_from(@context.snapshot_path.dirname).to_s})

			else
				uri = @context.file_route_to(config.res_dir_path + 'pinkyblog/print.css')
				Amrita.a({:href => uri})
				
			end
		end
		
		def scripts
			re = []
			script_names.each do |name|
				re << {:src => @context.file_route_to(config.res_dir_path + "pinkyblog/script/#{name}")}
			end
			
			re
		end
		
		def script_names
			re = %w(jquery.min.js jquery.textarearesizer.js base.js)
			
			re
		end
		
		
		
		def atom_link
			Amrita.a({:href => @context.get_feed_url('created.xml')}) unless snapshot_mode?
		end

		

		def links
			models = []
			models << {:rel => 'index', :href => @context.route_to('entries')}
			models << {:rel => 'home', :href => config.home_url} if config.home_url
			models << {:rel => 'search', :href => @context.route_to('search')}
			if up_href then
				models << {:rel => 'up', :href => up_href}
			end
			
			return models
		end
		
		def page_footer
			model = {}
			model[:top_href] = '#PAGETOP'
			model[:address_items] = []
			index = 2
			
			config.extra_addresses.each do |address_data|
				model[:address_items] << {:id => sprintf("FOOTER%02d", index), :caption => address_data['caption'], :href => address_data['href']}
				index += 1
			end
			
			if config.writer_address then
				#href = Util.get_html_entity("mailto:#{config.writer_address}")
				#model[:address_items] << {:id => sprintf("FOOTER%02d", index), :caption => 'mail', :title => '執筆者にメールを送る',
				#                          :href => Amrita::SanitizedString.new(href)}
				#index += 1
			end
			
			
			model[:address_items] << {:id => sprintf("FOOTER%02d", index), :caption => 'CSS Designplate',
			                          :title => 'CSS着せ替えテンプレートプロジェクト', :href => 'http://css-designplate.info/'}
			index += 1
			
			model[:address_items] << {:id => sprintf("FOOTER%02d", index), :caption => 'Pinky:blog',
			                          :title => 'このblogツールの配布サイト', :href => 'http://scl.littlestar.jp/pinkyblog/'}

			
			return model
		end
		
		
		def sections
			[]
		end
		
		def kizi
			sects = []
			unless @context.warnings.empty? then
				sects << gen_sect(WarningSection)
			end
			
			if request.cookies['message'] then
				sects << gen_sect(MessageSection, {:message => request.cookies['message']})
			end
			
			if @message then
				sects << gen_sect(MessageSection, {:message => @message})
			end
			
			sects << self.sections
			
			if @context.master_mode? and request.params['debug'] then
				sects << gen_sect(DebugInformationSection)
			end
			
			return sects
		end
		
		def custom_html_head
			Amrita::SanitizedString.new(@custom_html[:head] || '')
		end

		def custom_html_kizi_foot
			Amrita::SanitizedString.new(@custom_html[:kizi_foot] || '')
		end
		
		def custom_html_body_foot
			Amrita::SanitizedString.new(@custom_html[:body_foot] || '')
		end

		
		def http_status
			HTTP_OK
		end
		
		
		def to_s
			path = config.lib_dir_path + 'pinkyblog/template/main.html'
			text = path.read.untaint
			tmpl = Amrita::TemplateText.new(text)
			tmpl.amrita_id = 'amrita_src'
			buf = ""

			tmpl.expand(buf, self)

			return @context.parse_html(buf)

		end
		
		
		def headers
			re = {}
			re['Content-Type'] = 'text/html'
			etag = get_etag
			re['ETag'] = etag if etag
			
			re
		end
		
		# 文字列etag_baseを基に、MD5でEtagを生成
		def get_etag
			if etag_base and !(@message) and !(request.cookies['message']) then
				Digest::MD5.hexdigest(etag_base)
			end
		end
		
		def etag_base
			nil
		end
		
		def to_rack_response
			if config.use_conditional_get and not @context.master_mode? then
				etag = get_etag
				
				if_match = request.env['HTTP_IF_MATCH']
				if_none_match = request.env['HTTP_IF_NONE_MATCH']
				if_modified_since = request.env['HTTP_IF_MODIFIED_SINCE']
				if_unmodified_since = request.env['HTTP_IF_UNMODIFIED_SINCE']
				
				if (if_match and etag != if_match) or (if_none_match and etag == if_none_match) then
					re = Rack::Response.new('', 304, {'Content-Type' => nil})
				end
				
				# 今のところIf-Modified-Sinceには未対応（更新日時を得る手段を定義していないため）
				#if (if_modified_since and Time.now < Time.httpdate(if_modified_since))
				#or (if_unmodified_since and Time.now > Time.httpdate(if_unmodified_since)) then
				#	re = Rack::Response.new('', HTTP_NOT_MODIFIED, {'Content-Type' => nil})
				#end
			end
			
			re ||= Rack::Response.new(self.to_s, self.http_status, self.headers)

			set_message_eating_cookie(re)
			
			@cookie_data.each do |name, value|
				re.set_cookie(name, value)
			end
			
			re
		end
		
		def snapshot(root_path)
			path = root_path + @context.snapshot_path
			path.untaint
			FileUtils.mkdir_p(path.dirname)
			path.open('w'){|f|
				f.write(self.to_s)
			}
			return nil
		end
		

		
	end
	
=begin
	# 出力キャッシュ。HTML自体を内容に持つ
	class Cache
		def initialize(html)
			@html = html
		end
	
		def out(cgi)
			headers = {}
			headers['type'] = 'text/html'
			headers['status'] = HTTTP_OK
			
			cgi.out(headers){@html}
			return nil
		end
	end
=end
	
	
	class ErrorScreen < Screen
		require_opt :error_message
		attr_reader :error_message
		default_opt :http_status, HTTP_BAD_REQUEST
		
		def page_title
			return "#{@http_status} - #{config.site_title}"
		end
		
		def http_status
			@http_status
		end
		
		def sections
			[gen_sect(ErrorSection, {:body => @error_message, :http_status => @http_status})]
		end
		
	end
	
	class PostBlockScreen < Screen
		def page_title
			return "#{HTTP_BAD_REQUEST} - #{config.site_title}"
		end
		
		def http_status
			HTTP_BAD_REQUEST
		end
		
		def sections
			[gen_sect(PostBlockSection)]
		end
	end

	
	class ForbiddenScreen < Screen
		def page_title
			return "#{@http_status} - " + config.site_title
		end
		
		def sections
			body = "あなたは管理者としてログインした状態にありません。
			        正常にログインできない場合、ブラウザのCookie機能が有効になっているかどうか
			        確認してください。"
			
			return [gen_sect(ErrorSection, {:body => body, :http_status => HTTP_FORBIDDEN})]
			
		end
		
		def http_status
			HTTP_FORBIDDEN
		end
	end
	
	class TopScreen < Screen
		require_opt :recent_entries, :welcome_entry, :attached_images
	
		def page_title
			return config.site_title
		end
		
		def sections
			sections = super
			
			if master_mode? or @welcome_entry.visible? then
				sections << gen_sect(EntrySection, {:entry => @welcome_entry, :module_handler => @module_handler, :attached_images => @attached_images})
			end
			
			if not snapshot_mode? then
				sections << gen_sect(HeadlineSection, {:entries => @recent_entries})
				sections << gen_sect(MessageFormSection) if config.message_form_visible
			end
			return sections
		end
		
		def etag_base
			re = @context.etag_base
			re << @recent_entries.map{|x| x.etag_base}.join
			re << @welcome_entry.etag_base
			
			re
		end
		


	end
	
	class AboutScreen < Screen
		require_opt :about_blog_entry, :about_writer_entry, :attached_image_table
	
		def page_title
			return "このblogについて - #{config.site_title}"
		end
		

		
		def sections
			sections = super
			
			if master_mode? || @about_blog_entry.visible? then
				sections << gen_sect(EntrySection, {:entry => @about_blog_entry, :module_handler => @module_handler,
				                                    :attached_images => @attached_image_table['about_blog']}) 
			end
			
			if master_mode? || @about_writer_entry.visible? then
				sections << gen_sect(EntrySection, {:entry => @about_writer_entry, :module_handler => @module_handler,
				                                    :attached_images => @attached_image_table['about_writer']})
			end
			return sections
		end
		
		def pan_data
			data = super
			data << ['/about', @context.current_caption_on_menu]
			return data
		end
		
		def etag_base
			"#{@context.etag_base}#{@about_blog_entry.etag_base}#{@about_writer_entry.etag_base}"
		end

	end
	
	class MessageResponseScreen < Screen
		require_opt :entry
		
		def page_title
			return "メッセージレス - #{config.site_title}"
		end
		
		def sections
			return [gen_sect(EntrySection, {:entry => @entry, :module_handler => @module_handler, :ex_footer_visible => false})]
		end

		def pan_data
			data = super
			data << ['message_response', 'ひとことレス']
			return data
		end

	end

	class AttachedImageScreen < Screen
		require_opt :entry, :image
	
		
		def page_title
			return "#{@image.name} - #{config.site_title}"
		end

		
		def sections
			re = super		
			re << gen_sect(AttachedImageSection, {:entry => @entry, :image => @image})
			
			re
		end
		
		def pan_data
			data = super
			data << ["/entries/#{@entry.id}", @entry.title]
			data << ["/entries/#{@entry.id}/attached/#{@image.name}", @image.name]
			return data
		end

		def etag_base
			"#{@context.etag_base}#{@image.etag_base}"
		end
	end

	
	class EntryScreen < Screen
		require_opt :entry, :referer_list, :attached_images
		default_opt :simple_mode, false
		
		def page_title
			return "#{@entry.title} - #{config.site_title}"
		end

		
		def sections
			sections = super
			
			
			sections << gen_sect(EntrySection, @options.merge(:ex_footer_visible => false))
			
			unless @simple_mode then
				if config.use_comment? and @entry.commentable? then
					sections << gen_sect(CommentSection, @options.merge(:comments => @entry.comments)) unless @entry.existing_comments.empty?
					
					opts = {}
					opts[:entry_id] = @entry.id
					opts[:default_name] = request.cookies['default_name']
					opts[:default_address] = request.cookies['default_address']
					sections << gen_sect(CommentFormSection, opts) unless snapshot_mode?
				end
				sections << gen_sect(EntryInformationSection, @options)
			end
			
			return sections
		end
		
		def pan_data
			data = super
			data << [@entry.id, @entry.title]
			return data
		end

		def etag_base
			"#{@context.etag_base}#{@entry.etag_base}"
		end
	end
	
	class EntriesScreen < Screen
		require_opt :entries, :title, :attached_image_table
		
		def page_title
			return "#{@title} - #{config.site_title}"
		end

		
		def sections
			sections = super
			@entries.each do |entry|
				sections << gen_sect(EntrySection, @options.merge({:entry => entry, :attached_images => @attached_image_table[entry.id], :ex_footer_visible => false}))
			end
			
			return sections
		end
		
		def pan_data
			data = super
			data << [@entries.map{|x| x.id}.join(';'), @title]
			return data
		end

		def etag_base
			"#{@context.etag_base}" + @entries.map{|x| x.etag_base}.join
		end
	end

	
	class EntryEditScreen < Screen
		require_opt :entry, :tag_list, :attached_images
		default_opt :parameters, nil
		
		def page_title
			return "#{@entry.title}の編集 - #{config.site_title}"
		end

		
		def sections
			sections = super
			if @parameters then
				sections <<	gen_sect(PreviewSection, @options.merge({:content => @parameters[:content], :format => @parameters[:format],
				                                                     :image_display => @parameters[:image_display]}))
			end

			sections << gen_sect(EntryEditFormSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ["entries/#{@entry.id}", @entry.title]
			data << ["entries/#{@entry.id}/edit_form", "編集"]
			return data
		end
	end
	
	class CommentEditScreen < Screen
		require_opt :entry, :comment_index
		
		def page_title
			return "#{@entry.title} / コメント#{@comment_index + 1}番を編集 - #{config.site_title}"
		end

		
		def sections
			sections = super
			comment = @entry.comments[@comment_index]
			sections << gen_sect(CommentEditFormSection, @options.merge(:entry_id => @entry.id, :default_name => comment.writer, :default_address => comment.mail_address, :default_content => comment.content))
			sections << gen_sect(CommentDeleteFormSection, @options.merge(:entry_id => @entry.id, :default_name => comment.writer, :default_address => comment.mail_address, :default_content => comment.content))
			return sections
		end
		
		def pan_data
			data = super
			data << ["entries/#{@entry.id}", @entry.title]
			data << ["entries/#{@entry.id}/comments/#{@comment_index}/edit_form", "コメント#{@comment_index + 1}番の編集"]
			return data
		end
	end

	
	class EntryAddScreen < Screen
		require_opt :tag_list
		default_opt :parameters, nil

		
		def page_title
			return "新しい記事の作成 - #{config.site_title}"
		end

		
		def sections
			sections = super
			if @parameters then
				sections <<	gen_sect(PreviewSection, @options.merge({:content => @parameters[:content], :format => @parameters[:format],
				                                                     :image_display => @parameters[:image_display]}))
			end
			sections << gen_sect(EntryEditFormSection, @options.merge({:entry => nil}))
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', "管理者メニュー"]
			data << ["master_menu/entry_add_form", "新しい記事の作成"]
			return data
		end
	end

	
	class FormatGuideScreen < Screen
		def page_title
			return "記事の書き方について - #{config.site_title}"
		end

		
		def sections
			sections = super
			sections <<	gen_sect(FormatGuideSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ['format_guide', "記事の書き方について"]
			return data
		end
	end
	
	class FormatDetailScreen < Screen
		def page_title
			
			return "#{@module_handler.translator_modules[format_name]::CAPTION} - #{config.site_title}"
		end
		
		def format_name
			request.path_info.split('/').last
		end

		
		def sections
			sections = super
			sections <<	gen_sect(FormatDetailSection, @options)
			#sections <<	gen_sect(FormatDetailSourceSection)
			return sections
		end
		
		def pan_data
			data = super
			data << ['/format_guide', "記事の書き方について"]
			#data << ["/format_guide/#{format_name}", module_handler.translator_modules[format_name]::CAPTION]
			return data
		end
	end

	
	class PagingScreen < Screen
		def add_navigation(sections)
			type = config.page_changing_type
		
			opts = {:prev_href => prev_href, :prev_caption => prev_caption,
			        :next_href => nil, :next_caption => nil,
							:page_length => page_length, :total => total, :start => start, :extend_query => extend_query}
			if type == PCT::INDEX or (type == PCT::SEQUENTIAL and prev_href) then
				sections.unshift(gen_sect(NavigationSection, opts)) 
			end
			
			opts.merge!({:prev_href => nil, :prev_caption => nil,
			             :next_href => next_href, :next_caption => next_caption})
			if type == PCT::INDEX or (type == PCT::SEQUENTIAL and next_href) then
				sections.push(gen_sect(NavigationSection, opts))
			end			
			return sections
		end
		
		def start
			@start || request.start
		end
		
		def prev_caption
			number = [page_length, start].min
			"&lt;&lt;新しい#{number}記事"
		end
		
		def next_caption
			number = [page_length, total - start - page_length].min
			"過去の#{number}記事&gt;&gt;"
		end
		
		def extend_query
			nil
		end

		
		def prev_href
			if start > 0 then
				prev_start = start - page_length
				prev_start = 0 if prev_start < 0
				if snapshot_mode? then
					return @context.route_to(sprintf("%s_st%05d", paging_base_path, prev_start))
				else
					query = "start=#{prev_start}"
					query << '&' << extend_query if extend_query
					return @context.route_to(paging_base_path, query)
				end
			else
				return nil
			end
			
		end
		
		def next_href
			
			if (start + page_length) < total then
				next_start = start + page_length
				if snapshot_mode? then
					return @context.route_to(sprintf("%s_st%05d", paging_base_path, next_start))
				else
					query = "start=#{next_start}"
					query << '&' << extend_query if extend_query
					return @context.route_to(paging_base_path, query)
				end
			else
				return nil
			end
			
		end
		
		
		def page_range
			start...(start + page_length)
		end
		
		def get_page_pan
			last = [page_range.last, total].min
			caption = "#{page_range.first + 1} - #{last} (全 #{total} 記事)"
			return [paging_base_path, caption]
		end
		

		
		def links
			models = super
			models << {:rel => 'prev', :href => prev_href} if prev_href
			models << {:rel => 'next', :href => next_href} if next_href
			
			return models
		end

		
	end
	
	class EntryListScreen < PagingScreen
		require_opt :entries
		default_opt :tag_list, {}
		default_opt :access_counts, {}
	
		def initialize(context, opts = {})
			super
			
			# タグ絞込み
			unless request.tags.empty? then
				@entries.delete_if{|x| (request.tags - x.tags).size >= 1}
			end


		end
		
		def paging_base_path
			'entries'
		end
		
		
		def page_length
			ENTRY_LIST_PAGE_LENGTH
		end
		
		def total
			@entries.size
		end
		

		
		def page_title
			return "#{@context.current_caption_on_menu} - #{config.site_title}"
		end
		
		def extend_query
			query = "sort=#{request.sort}"
			if request.get_param('order') then
				query << '&order=' << request.get_param('order')
			end
			unless request.tags.empty? then
				query << '&' << request.tags.map{|x| "tags=" + Util.encode_base64url(x)}.join('&')
			end
			return query
		end
		
		def sections
			sections = super
			
			@entries = @entries.dup
			# タグ絞込み
			#unless request.tags.empty? then
			#	@entries.all?{|x| (request.tags - x.tags).empty?}
			#end

			case request.sort
			when Sort::BY_CREATED
				@entries.sort!{|a, b| b.created <=> a.created}
			when Sort::BY_ACCESS
				@entries.sort!{|a, b| (@access_counts[b.id] || 0) <=> (@access_counts[a.id] || 0)}
			when Sort::BY_MODIFIED
				@entries.sort!{|a, b| b.last_modified <=> a.last_modified}
			when Sort::BY_FILE_SIZE
				@entries.sort!{|a, b| b.content.length <=> a.content.length}
			when Sort::BY_TITLE
				@entries.sort!{|a, b| a.title <=> b.title}
			end
			
			
			# 逆順処理
			if request.get_param('order') == Order::REVERSE then
				@entries.reverse!
			end

			
			

			
			
			sections << gen_sect(TagListSection, {:tag_list => @tag_list}) unless snapshot_mode?
			sections << gen_sect(EntryListSection,
			                     {:entries => @entries[page_range], :access_counts => @access_counts})
			add_navigation(sections)
			
			return sections
		end
		
		def pan_data
			data = super
			data << ['entries', @context.current_caption_on_menu]
			data << get_page_pan
			return data.compact
		end
		
		def up_href
			@context.route_to('/')
		end
		


	end
	
	class RecentScreen < PagingScreen
		require_opt :entries, :attached_image_table, :module_handler
		default_opt :page_length, RECENT_ENTRY_PAGE_LENGTH

		def initialize(context, opts = {})
			super
			
			@entries.sort!{|a, b| b.last_modified <=> a.last_modified}

		end

		
		def paging_base_path
			'recent'
		end
		
		
		
		def page_length
			@page_length
		end
		
		def total
			@entries.size
		end
		
		def page_title
			return "#{@context.current_caption_on_menu} - #{config.site_title}"
		end
		
		def extend_query
			
			query = "number=#{@page_length}"
			unless request.tags.empty? then
				query << '&' << request.tags.map{|x| "tags=" + Util.encode_base64url(x)}.join('&')
			end
			return query
		end
		
		def sections
			sections = super
			

			
			@entries[page_range].each do |entry|
				sections << gen_sect(EntrySection, {:entry => entry, :module_handler => @module_handler,
				                     :attached_images => @attached_image_table[entry.id] || []})
			end
			add_navigation(sections)
			
			return sections
		end
		
		def pan_data
			data = super
			data << ['/recent', @context.current_caption_on_menu] unless @context.on_top_page?
			data << get_page_pan
			return data.compact
		end
		
		def up_href
			@context.route_to('/')
		end
		
		def etag_base
			"#{@context.etag_base}#{@entries[page_range].map{|x| x.etag_base}.join}"
		end



	end


	class SearchScreen < Screen
		require_opt :keywords, :hit_list
		
		def page_title
			return "#{@context.current_caption_on_menu} - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(SearchFormSection, {:keywords => @keywords})
			unless @keywords.empty? then
				sections << gen_sect(SearchResultSection, {:keywords => @keywords, :hit_list => @hit_list}) 
			end
			return sections
		end
		
		def pan_data
			data = super
			data << ['search', @context.current_caption_on_menu] unless @context.on_top_page?
			return data
		end
		
		def etag_base
			if @keywords.empty? then
				@context.etag_base
			end
		end

		
	end
	
	class NewsFeedScreen < Screen
		def page_title
			return "#{@context.current_caption_on_menu} - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(NewsFeedSection)
			return sections
		end
		
		def pan_data
			data = super
			data << ['news_feed', @context.current_caption_on_menu] unless @context.on_top_page?
			return data
		end
		
		def etag_base
			@context.etag_base
		end

		
	end


	class SystemMonitorScreen < Screen
		def page_title
			"システムモニター - #{config.site_title}"
		end
		
		def sections
			sects = super
			sects << gen_sect(SystemMonitorSection, @options)
			return sects
		end
		
		def pan_data
			re = super
			re << ['/system_monitor', 'システムモニター']
			
			re
		end
	end

	class FileTreeScreen < Screen
		require_opt :root
	
		def page_title
			"ファイルツリー（#{@root}） - #{config.site_title}"
		end
		
		def sections
			sects = super
			sects << gen_sect(FileTreeSection, @options)
			return sects
		end
		
		def pan_data
			re = super
			re << ['/system_monitor', 'システムモニター']
			re << [request.path_info, "ファイルツリー（#{@root}）"]
			
			re
		end
	end
	
	class ParityCheckScreen < Screen
		def page_title
			"ファイル状態チェック - #{config.site_title}"
		end
		
		def sections
			sects = super
			sects << gen_sect(ParityCheckSection, @options)
			return sects
		end
		
		def pan_data
			re = super
			re << ['/system_monitor', 'システムモニター']
			re << ['/system_monitor/parity_check', "ファイル状態チェック"]
			
			re
		end
	end




	class LoginFormScreen < Screen
		def page_title
			return "#{@context.current_menu_item ? @context.current_caption_on_menu : 'ログインフォーム'} - #{config.site_title}"
		end
		
		def sections
			
			return super + [gen_sect(LoginFormSection)]
		end
		
		def pan_data
			data = super
			unless @context.on_top_page? then
				data << ['login', (@context.current_menu_item ? @context.current_caption_on_menu : 'ログインフォーム')] 
			end
			return data
		end
		
	end

	class MasterMenuScreen < Screen
		require_opt :notifications
	
		
		def page_title
			return "#{@context.current_caption_on_menu} - #{config.site_title}"
		end
		
		def sections
			sects = super
			sects << gen_sect(NotifyingSection, {:notifications => @notifications}) unless @notifications.empty?
			sects << gen_sect(MasterMenuSection)
			sects << gen_sect(SystemInformationSection)
			return sects
		end
		
		def pan_data
			data = super
			data << ['master_menu', @context.current_caption_on_menu] unless @context.on_top_page?
			return data
		end
	end
	
	class BlogConfigScreen < Screen
		require_opt :module_handler
		
		def page_title
			return "blog設定 - #{config.site_title}"
		end
		
		def sections
			return super + [gen_sect(BlogConfigFormSection, @options)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/blog_config', 'blog設定']
			return data
		end
	end
	
	class MenuEditScreen < Screen
		require_opt :menu_text
		
		def page_title
			return "メニュー編集 - #{config.site_title}"
		end
		
		def sections
			return super + [gen_sect(MenuEditFormSection, @options)]
		end
		
		def pan_data
			data = super
			data << ['/master_menu', '管理者メニュー']
			data << ['/master_menu/menu_edit_form/simple', 'メニュー編集']
			return data
		end
	end
	
	class DirectMenuEditScreen < Screen
		require_opt :menu_text
		
		def page_title
			return "メニュー編集（もっと細かく） - #{config.site_title}"
		end
		
		def sections
			return super + [gen_sect(DirectMenuEditFormSection, @options), gen_sect(MenuCommandListSection)]
		end
		
		def pan_data
			data = super
			data << ['/master_menu', '管理者メニュー']
			data << ['/master_menu/menu_edit_form/simple', 'メニュー編集']
			data << ['/master_menu/menu_edit_form/direct', 'もっと細かく']
			return data
		end
	end


	
	class PostLimitScreen < Screen
		
		def page_title
			return "投稿制限 - #{config.site_title}"
		end
		
		def sections
			return super + [gen_sect(PostLimitFormSection)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/post_limit', '投稿制限']
			return data
		end
	end



	class RefererConfigScreen < Screen
		require_opt :table, :table_text
	
		
		def page_title
			return "リファラ設定 - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(RefererTableSection, {:table => @table})
			sections << gen_sect(RefererTableEditFormSection, {:table_text => @table_text})
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/referer_config', 'リファラ設定']
			return data
		end
	end
	
	class MailNotificationConfigScreen < Screen
		
		def page_title
			return "メール通知設定 - #{config.site_title}"
		end
		
		def sections
			return super + [gen_sect(MailNotificationConfigFormSection)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/mail_notification_config', 'メール通知設定']
			return data
		end
	end
	
	class HTMLCustomizeScreen < Screen
	
		
		def page_title
			return "HTMLカスタマイズ - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(HTMLCustomizeFormSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/html_customize', 'HTMLカスタマイズ']
			return data
		end
	end



	
	class MessageListScreen < Screen
		require_opt :messages
		
		def page_title
			return "ひとことメッセージ一覧 - #{config.site_title}"
		end
		
		def sections
			sects = super
			sects << gen_sect(MessageListSection, {:messages => @messages})
			return sects
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/message_list', 'ひとことメッセージ一覧']
			return data
		end
		

	end
	
	

	
	
	
	class EntryManagerScreen < Screen
		require_opt :entries, :access_record, :file_data, :attached_image_table
		
		def page_title
			return "記事の管理・一括操作 - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(EntryManagerSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/entry_manager', '記事の管理・一括操作']
			return data
		end
	end
	

	
	class EntryDeleteConfirmationScreen < Screen
		require_opt :entries, :access_record, :file_data

		def page_title
			return "記事の削除確認 - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(EntryDeleteConfirmationSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/entry_manager', '記事の管理・一括操作']
			data << ['master_menu/entry_manager', '削除確認']
			return data
		end
	end
	
	class EntryTimestampChangeScreen < Screen
		require_opt :entries

		def page_title
			return "作成/更新日時の変更 - #{config.site_title}"
		end
		
		def sections
			sections = super
			sections << gen_sect(EntryTimestampChangeFormSection, @options)
			return sections
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/entry_manager', '記事の管理・一括操作']
			data << ['master_menu/entry_manager', '作成/更新日時の変更']
			return data
		end
	end


	class ImportFormScreen < Screen
		def page_title
			return "インポート - #{config.site_title}"
		end
		
		def sections
			super + [gen_sect(ImportFormSection, @options)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/import', 'インポート']
			return data
		end
	end
	
	class ImportEntrySelectScreen < Screen
		require_opt :new_entry_data, :overlap_entry_data
	
		def page_title
			return "インポートする記事の選択 - #{config.site_title}"
		end
		
		def sections
			super + [gen_sect(ImportEntrySelectFormSection, @options)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/import', 'インポート']
			data << [nil, '記事選択']
			return data
		end
	end

	
	class ExportFormatSelectScreen < Screen
		def page_title
			return "エクスポート:出力形式の選択 - #{config.site_title}"
		end
		
		def sections
			re = super
			re << gen_sect(ExportFormatSelectSection, @options)
			
			re
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/export', 'エクスポート']
			return data
		end
	end

	class ExportByMTCompatibleScreen < Screen
		def page_title
			return "エクスポート:MovableType互換形式で出力 - #{config.site_title}"
		end
		
		def sections
			re = super
			re << gen_sect(ExportByMTCompatibleFormSection, @options)
			
			re
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/export', 'エクスポート']
			data << ['master_menu/export/mt-compatible', 'MovableType互換形式']
			return data
		end
	end
	
	class ExportByPblogScreen < Screen
		require_opt :zlib_installed
	
		def page_title
			return "エクスポート:pblog形式で出力 - #{config.site_title}"
		end
		
		def sections
			re = super
			re << gen_sect(ExportByPblogFormSection, @options)
			
			re
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/export', 'エクスポート']
			data << ['master_menu/export/pblog', 'pblog形式']
			return data
		end
	end


	class ExportResultScreen < Screen
		def page_title
			return "エクスポート:完了 - #{config.site_title}"
		end
		
		def sections
			re = super
			re << gen_sect(ExportResultSection, @options)
			
			re
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/export', 'エクスポート']
			data << ['master_menu/export/result', '完了']
			return data
		end
	end




	class SnapshotScreen < Screen


		def page_title
			return "スナップショット - #{config.site_title}"
		end
		
		def sections
			[gen_sect(SnapshotSection, @options)]
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/snapshot', 'スナップショット']
			return data
		end
	end
	
	class SnapshotResultScreen < Screen
		def page_title
			return "スナップショット:完了 - #{config.site_title}"
		end
		
		def sections
			re = super
			re << gen_sect(SnapshotResultSection, @options)
			
			re
		end
		
		def pan_data
			data = super
			data << ['master_menu', '管理者メニュー']
			data << ['master_menu/snapshot', 'エクスポート']
			data << ['master_menu/snapshot/result', '完了']
			return data
		end
	end

	
	class JSONResponse < Response
		require_opt :data
		
		def to_s
			AnJSON.build(@data)
		end
		
		def http_status
			HTTP_OK
		end
		
		def headers
			{'Content-Type' => 'application/json'}
		end
		
		def to_rack_response
			Rack::Response.new(self.to_s, self.http_status, self.headers)
		end
	end


	# リダイレクションを表す抽象クラス
	class Redirector < Response
		
		require_opt :path
		attr_reader :path, :query
		default_opt :message, nil
		
		
		def http_status
			HTTP_SEE_OTHER
		end
		
		def headers
			re = {}
			re['Location'] = location

			re
		end
		
		def location
			@context.absolute_uri_to(@path, @query).to_s
		end
		
		def to_s
			%Q|<html><body>go to url: <a href="#{location}">#{location}</a></body></html>|
		end
		
		
		
		def to_rack_response
			re =  Rack::Response.new(self.to_s, self.http_status, self.headers)
			if @message then
				re.set_cookie('message', {:value => @message, :path => @context.cookie_path})
			else
				set_message_eating_cookie(re)
			end
			if @cookie_data then
				@cookie_data.each do |key, value|
					re.set_cookie(key, value)
				end
			end
			
		
			re
		end
		
	end
	
	
=begin
	class AtomResponse < Screen
		
		def content_type
			'application/atom+xml'
		end

		def headers
			re = super
			re['Content-Type'] = content_type
			
			re
		end
		
		def cookies
			[]
		end
		
		def to_s			
			re = ''
			REXML::Formatters::Default.new.write(self.get_xml, re)
			
			re

		end
		
		private
		def entry_to_atom_entry(entry)
			re = Atom::Entry.new
			re.id = entry.id
			re.title = entry.title
			re.updated = entry.updated
			re.published = entry.published
			re.links << Atom::Link.new
			re.links.last['href'] = @context.absolute_uri_to("/entries/#{entry.id}")
			
			re
			
		end


	end

	class AtomService < AtomResponse
		def content_type
			'application/atomsvc+xml'
		end
		
		def get_xml
			svc = Atom::Service.new
			ws = Atom::Workspace.new(:title => config.site_title)

			cl = Atom::Collection.new(@context.absolute_uri_to('/app/version'))
			cl.title = 'Version Information'
			ws.collections << cl
			
			
			cl = Atom::Collection.new(@context.absolute_uri_to('/app/entries'))
			cl.title = 'All entries'
			ws.collections << cl
			
			svc.workspaces << ws
			
			return svc.to_xml
		end
		
	end
	
	class AtomEntryCollection < AtomResponse
		def initialize(context, entries)
			super(context)
			@entries = entries
		end
	
		def get_xml
			feed = Atom::Feed.new
			feed.id = @context.request.self_uri
			feed.title = config.site_title
			feed.updated = Time.now
			
			feed.entries = @entries.map{|x| entry_to_atom_entry(x)}
			
			return feed.to_xml
		end
	end
	
	class AtomEntry < AtomResponse
		def initialize(context, entry)
			super(context)
			@entry = entry
		end
	
		def get_xml
			return entry_to_atom_entry(@entry).to_xml
		end
	end

=end

	
end


