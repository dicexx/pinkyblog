# 汎用関数
require 'pathname'
require 'cgisup'
require 'kconv'
require 'uconv'
require 'digest/sha1'


module PinkyBlog
	module Util
		HTML_ESC = {
			'&' => '&amp;',
			'"' => '&quot;',
			'<' => '&lt;',
			'>' => '&gt;'
		}
		
	  # from http://jp.rubyist.net/magazine/?0010-CodeReview#l28
		def self.escape_html(str)
			table = HTML_ESC   # optimize
			str.gsub(/[&"<>]/n) {|s| table[s] }
		end
		
		def self.unescape_html(html)
			CGI.unescapeHTML(html)
		end
	
		
		def self.encode_url(url)
			CGI.escape(url)
		end
		
		def self.decode_url(encoded_url)
			CGI.unescape(encoded_url)
		end
	
		
		BASE64URL_ENCODING_TABLE = ['+/', '-_']
		# Base64エンコード+URIやファイル名に使える記号に置換
		def self.encode_base64url(str)
			return [str].pack('m*').gsub(/\r|\n/, '').tr(BASE64URL_ENCODING_TABLE[0], BASE64URL_ENCODING_TABLE[1])
		end
		
		# ref:: encode_base64url
	 	def self.decode_base64url(encoded)
			return encoded.tr(BASE64URL_ENCODING_TABLE[1], BASE64URL_ENCODING_TABLE[0]).unpack('m*')[0]
		end
		
		# to HTTP query_string (return: String or nil)
		def self.tags_to_query(tags)
			if tags.empty? then
				return nil
			else
				buf = []
				tags.each_with_index do |tag, i|
					buf << "tags=#{self.encode_base64url(tag)}"
				end
				return buf.join('&')
			end
		end
		
		
		# ファイルサイズをKB表示の文字列に整形する
		# from http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-list/20450
		def self.size_to_kb(size)
			buf = (size / 1024.0).ceil.to_s # KB単位に変換、小数点以下は切り上げ
			buf = buf.reverse.scan(/\d{1,3}/).join(',').reverse # カンマを入れる
			
			return "#{buf} KB"
		end

		def self.size_to_b(size)
			buf = size.to_s.reverse.scan(/\d{1,3}/).join(',').reverse # カンマを入れる
			
			return "#{buf} byte"
		end

			
		# 指定した文字長を超える場合には省略
		CLIPPING_SUFFIX = ' ...'
		def self.clip(str, max_length)
			if str.length > max_length then
				str[0, max_length - CLIPPING_SUFFIX.length] + CLIPPING_SUFFIX
			else
				str
			end
		end


		# 指定したファイルのSHA-1ハッシュを計算して返す
		def self.digest_file(path)
			body = nil
			open(path, 'rb'){|f|
				body = f.read
			}
			
			return Digest::SHA1.hexdigest(body)
		end

		
		BOM_PATTERN = /^\xef\xbb\xbf/
		# UTF-8文字列の先頭にBOMがあった場合、これを削除
		def self.slice_bom(utf8str)
			return utf8str.sub(BOM_PATTERN, '')
		end
		
		
		
		# 指定したファイルをテキストモードで読み込む（BOMも削除）
		# 何らかの原因で読み込めない場合にはnilを返す
		def self.read_text(path)
			path = Pathname.new(path.to_s) unless path.is_a?(Pathname)
			
			if path.readable? then
				return self.slice_bom(path.read.gsub(/\r\n/, "\n"))
			else
				return nil
			end
		end
	
	 	# 指定したファイルに、文字列をテキストモードで書き込もうと試みる
		# ロックやエラーのハンドリングは行わない（エラーはそのまま外に投げる）
		def self.write_text(path, text, mode =  File::WRONLY|File::CREAT|File::TRUNC, permission = 0666)
			path = Pathname.new(path.to_s) unless path.is_a?(Pathname)
			
			open(path, mode, permission){|f|
				f.write text.gsub(/\r\n/, "\n")
			}
			
			return true
		end
		
		# 指定したパスのディレクトリがなければ作成
		# （更新日時は変更しない）
		def self.touch_dir(dir_path)
			if dir_path.exist? then
				return false
			else
				Dir.mkdir(dir_path)
				return true
			end
		end
		
		def self.page_number_to_file_name(base, num)
			sprintf("#{base}_page%05d.html", num)
		end
	
		STATIC_ENTRY_PATTERN = /\A[^0-9]/
		def self.static_entry_id?(id)
			id =~ STATIC_ENTRY_PATTERN
		end
		
		# メールアドレスやURLを実体参照に変換（自動収集プログラムへの対策）
		def self.get_html_entity(text)
			forced = ':@/'
			entity = ""
			text.each_byte do |c|
				# 強制変換文字以外は、3/4の確率で変換
				if forced.include?(c.chr) || rand(4) >= 1 then
					entity << "&##{c.to_i};"
				else
					entity << c.chr
				end
			end
			return entity
		end
		
		# ruby1.8.1以前のkconvはUTF-8に対応していないため、一度EUC-JPを経由している
		def self.encode_to_jis(str)
			Uconv.u8toeuc(str).kconv(Kconv::JIS, Kconv::EUC)
		end
		
		def self.encode_for_mail_header(str)
			'=?ISO-2022-JP?B?' + [encode_to_jis(str)].pack('m').gsub(/\n|\r\n/m, '') + '?='
		end
		
		def self.normalize_path(path)
			re = path.dup
			normalize_path!(re)
			
			re
		end
	
		
		def self.normalize_path!(path)
			unless path.slice(0, 1) == '/' then
				path.insert(0, '/')
			end
		end
		
		def self.get_image_size(path)
			w = nil; h = nil
			open(path, 'rb'){|f| w, h = ImageSize.new(f).get_size}
			return w, h
		end
		
	
		def self.encode_file_name(name)
			name.gsub(/[^a-zA-Z0-9._-]/) do |c|
				re = ''
				c.each_byte do |byte|
					re << sprintf('%02x', byte)
				end
				
				re
			end
		end
		
		def self.format_file_tree(root, level = 0)
			re = ""
			root = Pathname(root) unless root.respond_to?(:children)


			if root.directory? then
				re << "#{'  ' * level}|-+ #{root.basename}/\n"
				root.children.each do |child|
					child.untaint if level < 30
					re << format_file_tree(child, level + 1)
				end
				
			elsif root.file? then
				re << "#{'  ' * level}|-- #{root.basename}\n"
			end

			
			re
		end
	
		ENTRY_ID_PATTERN = /[a-zA-Z0-9_-]/
		ENTRY_ID_LENGTH = 60
	
		def self.validate_entry_id(id)
			if id =~ ENTRY_ID_PATTERN and id.length < ENTRY_ID_LENGTH then
				id.untaint
				return true
			else
				return false
			end
		end
		
		PASSWORD_RANGE = 4..16
		PASSWORD_PATTERN = /^[a-zA-Z0-9]+$/
		
		def self.validate_password(pass)
			unless pass =~ PASSWORD_PATTERN then
				return false
			end
			
			validate(pass, PASSWORD_RANGE)
		end
		
		def self.validate(str, range)
			if range.kind_of?(Fixnum) then
				range = (0..range)
			end
			
			if str.length.in?(range) then
				str.untaint
				return true
			else
				return false
			end
		end
		
		

	end
	
end



