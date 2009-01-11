# encoding: utf-8

require 'uri'
require 'rack/request'

require 'pinkyblog/util'
require 'pinkyblog/error'

# Rack::Requestを継承しているため、同様のインターフェースが使用可能
module PinkyBlog
	class Request < Rack::Request
		# 頻繁に使うため、計算結果をキャッシュするように変更
		def params
			@params ||= super
			return @params
		end
		
		def normalized_path
			Util.normalize_path(path_info)
		end
		
		def get_param(key)
			re = self.params[key]
			re = nil if re.kind_of?(String) and re.empty?
			
			re
		end
		
		def get_param_array(key)
			re = get_param(key) || []
			re = [re] if re.kind_of?(String)
			
			re
		end
		
		def get_param_str(key)
			get_param(key).to_s
		end
		
		alias get_param_string get_param_str
		
		# 本来はkeyの名前を'tags'にして、get_param_arrayを使えば良いはずなのだけれど
		# なぜかそれだけだとうまく動かない
		# （POSTの場合に限り、tagsの値が配列でなく文字列になってしまう。Rackのバグ？）
		def tags
			re = []
			
			# tagsの値を取得
			if self.params.include?('tags') then
				re += self.params['tags'].map{|x| Util.decode_base64url(x)}
			end
			
			# tags_*の値を取得
			self.params.each_pair do |key, value|
				if key =~ /^tags_\d+/ then
					re << Util.decode_base64url(value)
				end
			end
			
			re
		end
		
		def start
			self.params['start'].to_i || 0
		end
		
		def sort
			if get_param('sort') then
				get_param('sort')
			elsif get_param('submit_access') then
				Sort::BY_ACCESS
			elsif get_param('submit_created') then
				Sort::BY_CREATED
			elsif get_param('submit_file_size') then
				Sort::BY_FILE_SIZE
			elsif get_param('submit_title') then
				Sort::BY_TITLE
			else
				Sort::BY_MODIFIED
			end
		end
		
		def has_key?(k)
			@params.has_key?(k)
		end
		
		# Rack::Requestのcookiesは、同じ名前のcookieが複数あっても一つしか返さないため
		# このメソッドで複数cookieに対応
		def multiple_cookies
      return {}  unless @env["HTTP_COOKIE"]

      if @multiple_cookies then
        @multiple_cookies
      else
        @multiple_cookies = Rack::Utils.parse_query(@env["HTTP_COOKIE"], ';,')
      end
		end

		
		alias uri url
	end
	
end
