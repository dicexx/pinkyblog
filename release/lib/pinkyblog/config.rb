# コンフィグ
require 'pathname'
require 'anjson'
require 'rubyplus'

require 'pinkyblog/util'
require 'pinkyblog/menu'

module PinkyBlog
	class Config
		attr_writer :lib_dir_path, :data_dir_path, :mod_dir_path, :res_dir_path, :cdp_dir_path
	
		attr_accessor :home_url, :site_title, :about_visible
		attr_accessor :default_translator
		attr_accessor :master_password
		attr_accessor :http_server_port, :http_server_static_urls
		attr_accessor :writer_name, :writer_address, :headline_title
		#attr_accessor :page_changing_type
		attr_accessor :auto_date_display_type, :menu_type
		attr_accessor :extra_addresses
		attr_accessor :referer_visible
		
		bool_attr_accessor :use_comment
		attr_accessor :commentator_name_required, :commentator_address_required
		attr_accessor :message_form_visible, :message_form_title, :message_form_guide
		bool_attr_accessor :use_path_info
		bool_attr_accessor :auto_login

		attr_accessor :comment_length_limit, :message_length_limit
		attr_accessor :block_http, :block_ascii, :ng_words
		bool_attr_accessor :use_conditional_get
		bool_attr_accessor :use_javascript
		bool_attr_accessor :use_image_attaching
		bool_attr_accessor :use_tag
		
		attr_accessor :sendmail_path
		attr_accessor :mail_notification_to_addresses

		bool_attr_accessor :demo
		
		attr_accessor :menu

		attr_reader :latest_mtime, :latest_menu_mtime
		
		alias about_visible? about_visible
		alias referer_visible? referer_visible
		alias commentator_name_required? commentator_name_required
		alias commentator_address_required? commentator_address_required
		alias message_form_visible? message_form_visible
		alias default_format default_translator

		def initialize
			@master_password = 'test'
		
			@data_dir_path = './data/'
			@mod_dir_path = './mod/'
			@lib_dir_path = './lib/'
			@res_dir_path = './res/'
			@cdp_dir_path = './csstemplate/'
			
			@http_server_port = 8888
			@http_server_static_urls = []

			@default_translator = 'markdown'
			
			@home_url = nil
			@site_title = 'no title blog'
			@about_visible = true
			@referer_visible = true
			@writer_name = "no name writer"
			@writer_address = nil
			
			@headline_title = '最近の更新'
			
			@auto_date_display_type = ADDT::NO
			#@page_changing_type = PCT::SEQUENTIAL
			@menu_type = MT::SIMPLE
			
			@extra_addresses = []
			
			@auto_login = true
			
			@use_path_info = true
			
			@demo = false

			@use_comment = true
			@commentator_name_required = false
			@commentator_address_required = false
			
			@message_form_visible = true
			@message_form_title = "執筆者にひとことメッセージを送る"
			@message_form_guide = "ご意見・質問・突っ込みなど、ご自由にどうぞ。"
			
			@menu_captions = {}
			
			@comment_length_limit = 'loose'
			@message_length_limit = 'loose'
			@block_http = true
			@block_ascii = true
			@ng_words = []
			
			@use_javascript = true
			@use_image_attaching = true
			@use_tag = true
			@use_conditional_get = false
			
			@sendmail_path = nil
			@mail_notification_to_addresses = []
			
			@latest_mtime = nil
			@latest_menu_mtime = nil
			@extended_file_number = 0 # これを数えないと、設定ファイルが削除されてもETagが変化しないことがある
			
			@menu = Menu.parse(DEFAULT_MENU_TEXT)
		end
		
		def page_changing_type
			PCT::INDEX
		end
		
		def transform_for_spec
			@lib_dir_path = './'
		end
		
		def lib_dir_path
			Pathname.new(@lib_dir_path)
		end

		def data_dir_path
			Pathname.new(@data_dir_path)
		end
		
		def mod_dir_path
			Pathname.new(@mod_dir_path)
		end
		
		def res_dir_path
			Pathname.new(@res_dir_path)
		end
		
		def attached_dir_path
			res_dir_path + "attached/"
		end

		def feed_dir_path
			res_dir_path + "feed/"
		end
		
		def cdp_dir_path
			Pathname.new(@cdp_dir_path)
		end
		
		def cdp_file_path
			cdp_dir_path + 'style.css'
		end
		
		def real_message_length_limit
			LIMIT_TABLE[:message_length][@message_length_limit]
		end
		
		def real_comment_length_limit
			LIMIT_TABLE[:comment_length][@comment_length_limit]
		end
		
		def get_menu_caption(key)
			@menu_captions[key] || key.tr('_', ' ')
		end
		
		def check_spam(text)
			if @block_http then
				count = 0
				text.gsub(/http[s]?\:\/\//) do
					count += 1
					return true if count >= 5
				end
			end
			
			if @block_ascii then
				ascii_count = text.each_char.find_all{|c| c.length == 1}.size
				return true if (ascii_count.to_f / text.jlength) > 0.9
			end
			
			@ng_words.each do |word|
				return true if text =~ Regexp.new(Regexp.escape(word))
			end
			
			return false
		end


		
		def extend_json(path)
			if path.readable? then
				mtime = path.mtime
				if @latest_mtime.nil? or mtime > @latest_mtime then
					@latest_mtime = mtime
				end
				
				@extended_file_number += 1
				
				text = Util.read_text(path)
				data = AnJSON.parse(text)
				data.each_pair do |key, value|
					instance_variable_set("@#{key}", value)
				end
				return true
			else
				return false
			end
		end
		
		def etag_base
			"#{@extended_file_number.to_s} #{@latest_mtime.to_i} #{(@latest_menu_mtime ? @latest_menu_mtime.to_i : 0)} "
		end
		
		def load_menu
			menu_path = data_dir_path + 'menu.txt'
			text = Util.read_text(menu_path)
			if text then
				@menu = Menu.parse(text)
				@latest_menu_mtime = File.mtime(menu_path)
				return true
			else
				return false
			end

		end
		

		
		
		
		def Config.load(path)
			config = Config.new
			script = Util.read_text(path)
			script.untaint
			config.instance_eval(script)
			config.instance_variable_set('@latest_mtime', File.mtime(path))
			config.load_menu

			return config
		end
	end
	
	
	
end
