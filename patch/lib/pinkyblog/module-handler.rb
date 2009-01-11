require 'pathname'

require 'pinkyblog/config'
require 'pinkyblog/util'
require 'pinkyblog/request'

# モジュールのロード・呼び出しを行うクラス
module PinkyBlog
	class ModuleHandler
		attr_reader :translator_modules
		
		def self.load(config)
			return self.new(config)
		end
	
		def initialize(config)
			@config = config
			@translator_modules = {}
		end
		
		RB_PATTERN = /\A(.+)\.rb\z/
		
		
		def dir_path
			@config.mod_dir_path
		end
		
		def translator_dir_path
			self.dir_path + 'translator'
		end
		
		def load(data_handler_name)
			@translator_modules.clear
			translator_dir_path.children.each do |path|
				if path.cleanpath.basename.to_s =~ RB_PATTERN then
					name = $1
					path.untaint

					@translator_modules[name] = Module.new
					@translator_modules[name].const_set(:DIR_PATH, (translator_dir_path + name).untaint)
					@translator_modules[name].module_eval(path.read.untaint, path.to_s)
				end
			end
			
			
			
			return self
		end
		
		
		def translator_names
			@translator_modules.keys
		end
		
		def get_translator(name)
			if @translator_modules.has_key?(name) then
				@translator_modules[name]::Translator.new
			else
				return nil
			end
		end
		
		def translate(format_name, text)
			format_name ||= @config.default_translator
			translator = get_translator(format_name)
			if translator then
				begin
					return translator.text_to_html(text)
				rescue

					html = "<p><strong>テキスト→HTMLの変換でエラーが発生しました。</strong></p>\n"
					html << "<h3>エラーの内容：</h3>\n"
					html << "<pre>"
					html << Util.escape_html("#$! (#{$!.class})\n")
					html << Util.escape_html("#{$@.first}n")
					html << "</pre>"

					return html
				end
		
			else
				buf = ""
				buf << "<p><strong>#{format_name} トランスレータが見つかりません。
				        本文をテキストのままで表示します。</strong></p>"
				buf << "<pre>" << Util.escape_html(text) << "</pre>"
				return buf
			end


		end
		

		
	end
	
	class TranslatorAPI
		def initialize(view_context)
			@context = view_context
		end
		
		SPECIAL_LINK_PATTERN = /\A(.+?)\:(.+)\Z/

	end	
end
