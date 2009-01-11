# 
require 'pathname'
require 'timeout'
require 'fileutils'
require 'uuidtools'
require 'md'
require 'jcode'
require 'amrita/template'
require 'anjson'
require 'digest/sha1'

require 'pinkyblog/const'
require 'pinkyblog/util'
require 'pinkyblog/entry'
require 'pinkyblog/message'

module PinkyBlog
	# データ集合を現すクラス
	class Repository
		JSON_PARSER = AnJSON::Parser.new({:malformed_chr => '?'})
		attr_reader :dir_path
	
		def initialize(dir_path, checking = true)
			@dir_path = Pathname.new(dir_path)
			@in_transaction = false
			@ids_cache = nil
			@entries_cache = nil
			check_valid if checking
		end
		
		def clear_cache
			@ids_cache = nil
			@entries_cache = nil
		end
		
		TIMEOUT_SEC = 20
		def lock
		  begin
				locking_pattern = /_locking_[0-9]+\Z/
			
				# ロック検出
				if (lock_file_path = lock_dir_path.children.find{|x| x.to_s =~ locking_pattern}) then
					lock_file_path.untaint
					# ロックがかかっている間はループ
					timeout(TIMEOUT_SEC) do
						while lock_file_path.exist? do
							sleep(1)
						end
					end
				end
				
	
				# ロックが解除されていれば、ロックをかけてブロック実行
				lock_file_path = lock_dir_path + "./_locking_#{Time.now.to_i.to_s}"
				FileUtils.touch([lock_file_path])
				@in_transaction = true
				yield(self)
			rescue TimeoutError
				raise("file lock timeout - please retry.")
			ensure
				# ロック解除
				lock_file_path.delete
				@in_transaction = false
				clear_cache
			end
		end
		
		
		def check_valid
			unless @dir_path.writable? then
				raise Error, "データを格納するためのディレクトリ #{@dir_path} が読み込めません。\nディレクトリが存在しないか、またはパーミッションに問題があります。"
			end
		
			unless entry_dir_path.writable? then
				raise Error, "記事データを格納するためのディレクトリ #{entry_dir_path} が読み込めません。\nディレクトリが存在しないか、またはパーミッションに問題があります。"
			end
			
			unless lock_dir_path.writable? then
				raise Error, "ロック情報を作成するためのディレクトリ #{lock_dir_path} が読み込めません。\nディレクトリが存在しないか、またはパーミッションに問題があります。"
			end

		end
		
		
		
		def check_transaction
			raise("can't write, out of transaction") unless @in_transaction
		end
		
		def entry_dir_path
			@dir_path + './entry/'
		end
		
		def custom_html_dir_path
			@dir_path + './custom_html/'
		end
		
		def entry_trash_dir_path
			entry_dir_path + './trash/'
		end
		

		def get_entry_file_path(id)
			path = @dir_path + "entry/pb_#{id}.md"
			path.untaint
			return path
		end

		def feed_id_file_path
			@dir_path + './feed_id.json'
		end
		
		def access_data_file_path
			@dir_path + './access_data.json'
		end
		
		def blog_config_file_path
			@dir_path + './blog_config.json'
		end

		def post_limit_file_path
			@dir_path + './post_limit.json'
		end
		
		def referer_table_file_path
			@dir_path + './referer_table.md'
		end
		
		def mail_notification_config_file_path
			@dir_path + './mail_notification_config.json'
		end
		
		def preview_backup_file_path
			@dir_path + 'preview_backup.yml'
		end

		
		def lock_dir_path
			@dir_path + './lock/'
		end
		
		def message_file_path
			@dir_path + './messages.md'
		end
		
		def parity_file_path
			@dir_path + './parity.json'
		end
		
		def load_json(path)
			json = Util.read_text(path)
			if json then
				return JSON_PARSER.parse(json)
			else
				return nil
			end
		end
		
		def save_json(path, data)
			Util.write_text(path, AnJSON.pretty_build(data))
		end
		
		def load_parity
			data = load_json(parity_file_path) || {}
			data['entry'] ||= {}
			
			return data
		end
		
		def save_parity(data)
			save_json(parity_file_path, data)
		end

		def add_new_basic_entry(id, visible, title, content, format, opts = {})
			if get_entry_ids.include?(id) then
				return false
			else
				entry = BasicEntry.new(id, {:title => title, :content => content, :tags => opts[:tags] || [],
				                            :visible => visible, :format => format, :attached_image_display => opts[:attached_image_display]})
				save_entry(entry)
				
				return true
			end
		end
		
		def add_new_static_entry(id, visible, title, content, format, opts = {})
			if get_entry_ids.include?(id) then
				return false
			else
				entry = StaticEntry.new(id, {:title => title, :content => content, :visible => visible, :format => format,
				                             :attached_image_display => opts[:attached_image_display]})
				save_entry(entry)
				
				return true
			end
		end
		
		def edit_basic_entry(id, visible, title, content, format, opts = {})
			entry = load_entry(id)
			entry.visible = visible
			entry.title = title
			entry.content = content
			entry.format = format
			entry.tags = opts[:tags] if opts[:tags]
			entry.last_modified = Time.now
			entry.edited_number += 1
			entry.attached_image_display = opts[:attached_image_display]
			save_entry(entry)
		end
		
		def edit_static_entry(id, visible, title, content, format, opts = {})
			entry = load_entry(id)
			entry.title = title
			entry.visible = visible
			entry.content = content
			entry.format = format
			entry.last_modified = Time.now
			entry.edited_number += 1
			entry.attached_image_display = opts[:attached_image_display]
			save_entry(entry)
			
		end

		
		def comment_to_entry(id, writer, content, mail_address, password = nil)
			entry = load_entry(id)
			entry.comments << Comment.new(writer, content, mail_address, (password ? Digest::SHA1.hexdigest(password) : nil))
			save_entry(entry)
		end
		alias add_comment comment_to_entry
		

		
		def delete_entry(id)
			check_transaction
			
			Dir.mkdir(entry_trash_dir_path) unless entry_trash_dir_path.exist?
			FileUtils.mv([get_entry_file_path(id).to_s], entry_trash_dir_path)
		end
		

		
		def get_entry_ids
			ids = []
			file_pattern = /pb_(.+?)\.md\Z/
			
			if @ids_cache then
				ids = @ids_cache.dup
			else
				entry_dir_path.children.each do |file_path|
					if file_path.to_s =~ file_pattern then
						ids << $1
					end
				end
				@ids_cache = ids.dup
			end
			
			return ids
		end
		
		
		def load_all_entries(include_invisible_entry = false)
			
			if @entries_cache then
				entries = @entries_cache.dup
			else
				entries = []
				ids = get_entry_ids
				
				ids.each do |id|
					entries << load_entry(id)
				end
				@entries_cache = entries.dup
			end
			

			
			unless include_invisible_entry then
				entries.delete_if{|x| x.invisible?}
			end
			
			entries.delete_if{|x| x.kind_of?(StaticEntry)}


			return entries
		end
		
		
		def load_recent_entries(range, include_invisible_entry = false)
			range = 0...(range.to_i) unless range.is_a?(Range)
			entries = load_all_entries(include_invisible_entry)
			entries.sort!{|a, b| a.last_modified <=> b.last_modified}
			entries.reverse!
			return entries[range]
		end
		
		
		
		
		def load_entry(id)
			path = get_entry_file_path(id)
			text = Util.read_text(path)
			if text then
				md = MD.parse(text)
				return Entry.build_from_md(id, md)
			elsif Util.static_entry_id?(id)
				return StaticEntry.new(id)
			else
				return nil
			end
		
		end
		
		def save_entry(entry)
			check_transaction
			path = get_entry_file_path(entry.id)
			suc1 = Util.write_text(path, entry.to_md.to_s)
			
			data = load_parity
			data['entry'][entry.id] = Util.digest_file(path)
			suc2 = save_parity(data)
			
			return(suc1 && suc2)
		end
		
		
		
		def load_messages
			path = message_file_path
			text = Util.read_text(path)
			if text then
				md = MD.parse(text)
			else
				md = MD.new
			end
			
			return Message.build_from_md(md)
		end
		
		# メッセージを追加 (Return: true/false)
		def add_message(message)
			check_transaction
			messages = load_messages
			
			messages << Message.new(Time.now.to_i, message)
			
			md = MD.new(messages.map{|x| x.to_md_track})
			return Util.write_text(message_file_path, md.to_s)
		end
		
		def delete_messages(ids)
			check_transaction
			messages = load_messages
			messages.delete_if{|x| ids.include?(x.uuid)}

			md = MD.new(messages.map{|x| x.to_md_track})
			return Util.write_text(message_file_path, md.to_s)
		end
		
		def read_mark_messages
			check_transaction
			messages = load_messages
			
			messages.each{|x| x.read = true}
			
			md = MD.new(messages.map{|x| x.to_md_track})
			return Util.write_text(message_file_path, md.to_s)
		end
		
		def get_feed_ids(*request_keys)
			ids = load_json(feed_id_file_path) || {}
			
			# 見つからないIDがあれば作成
			unless (request_keys - ids.keys).empty? then
				request_keys.each{|x| ids[x] ||= UUID.random_create.to_s}
				unless save_json(feed_id_file_path, ids) then
					raise("フィードIDをファイルに記録できません。データディレクトリの有無とパーミッションを確認してください。")
				end
			end
			
			return ids
		end


		def load_blog_config
			load_json(blog_config_file_path) || {}
		end
		
		def save_blog_config(data)
			check_transaction
			save_json(blog_config_file_path, data)
		end



		def record_access(entry_id, referer_url, remote_address = nil)
			check_transaction
			data = load_access_data
			last_access = data['last_access_addresses'][entry_id.to_s]
			
			# 同一IPから、同じ記事へ連続アクセスがあった場合にはカウントしない
			unless last_access and remote_address and remote_address == last_access then
				data['counts'][entry_id.to_s] ||= 0
				data['counts'][entry_id.to_s] += 1
				
				if referer_url then
					data['referers'][entry_id.to_s] ||= {}
					data['referers'][entry_id.to_s][referer_url] ||= 0
					data['referers'][entry_id.to_s][referer_url] += 1
				end
				
				data['last_access_addresses'][entry_id.to_s] = remote_address
				
				save_json(access_data_file_path, data)
			end
				
			return nil
		end
		

		
		def load_access_data
			re = load_json(access_data_file_path)
			if re then
				re['counts'] ||= {}
				re['referers'] ||= {}
				re['last_access_addresses'] ||= {}

				re
			else
				{'counts' => {}, 'referers' => {}, 'last_access_addresses' => {}}
			end
		end
		
		
		# リファラ置換表（テキスト）を読み込む
		def load_referer_table
			text = Util.read_text(referer_table_file_path)
			if text && (md = MD.parse(text)) && (track = md.find_type('PinkyBlog/RefererTable')) then
				
				table = []
				pattern = /[\s　]+/
				track.body.each_line do |line|
					if line =~ pattern then
						url = $~.pre_match
						name = $~.post_match.chomp
						unless url.empty? || name.empty? then
							table << [url, name]
						end
					end
				end
				
				return table
			else
				return []
			end
		end
		
		def save_referer_table(text)
			check_transaction

			track = MD::Track.new
			track.type = 'PinkyBlog/RefererTable'
			track.body = text
			return Util.write_text(referer_table_file_path, MD.new([track]).to_s)
		end
		
		# 置換・ソート済みリファラ一覧をArrayで得る
		# Arrayの各要素は[部分URL, サイト名 or nil, カウント]の順
		def get_referer_list(entry_id)
			referer_counts = load_access_data['referers'][entry_id] || {}
			table = load_referer_table
			regexps = {}
			# 正規表現のコンパイルは先に済ませておく
			table.each do |partial_url, site_name|
				regexps[partial_url] = /^#{Regexp.escape(partial_url)}/
			end
			
			count_result = {}
			referer_counts.each do |full_url, count|
				matched_url, matched_name = table.find do |partial_url, site_name|
					full_url =~ regexps[partial_url]
				end
				
				if matched_url then
					count_result[matched_url] ||= 0
					count_result[matched_url] += count
				else
					count_result[full_url] ||= 0
					count_result[full_url] += count
				end
				
			end
			
			list = []
			count_result.each_pair do |url, count|
				found = table.find{|x, y| x == url}
				site_name = (found ? found[1] : nil)
				
				list << [url, site_name, count]
			end
			list.sort!{|a, b| b[2] <=> a[2]}
			return list
			
		end
		
		def get_tag_list(base_tags = [], include_hiddens = false)
			entries = load_all_entries(include_hiddens)
			tags = {}
			entries.each do |entry|
				next if base_tags.find{|x| !(entry.tags.include?(x))}
				
				
				(include_hiddens ? entry.tags : entry.normal_tags).each do |tag|
					tags[tag] ||= 0
					tags[tag] += 1
				end
			end
			
			# ベースとなったタグは含まない
			base_tags.each{|x| tags.delete(x)}
			
			return tags.to_a.sort{|a, b| b[1] <=> a[1]}

		end
		
		def search(keywords, include_hidden_entry = false, include_static_entry = false)
			entries = load_all_entries(include_hidden_entry)
			
			patterns = {}
			hits = {}
			pattern = Regexp.new(keywords.map{|x| Regexp.escape(x)}.join('|'))
			
			entries.each_index do |i|
				entry = entries[i]
				hits[i] = []

				# タイトル検索
				target = entry.title || ""
				length = target.jlength
				hit_keywords = []
				parts = []
				while target =~ pattern do
					parts << $~.pre_match
					parts << $~.to_s
					hit_keywords << $~.to_s
					target = $~.post_match
				end
				
				parts << target
				
				hits[i] << TitleSearchHit.new(hit_keywords, parts, length) unless parts.size <= 1
				
				
				# タグ検索
				hit_keywords = []
				tags = []
				entry.tags.each do |tag|
					if tag =~ pattern then
						hit_keywords << $~.to_s
						tags << tag
					end
				end
				
				hits[i] << TagSearchHit.new(hit_keywords, tags) unless tags.empty?


				# 本文検索
				target = entry.content || ""
				length = target.jlength
				hit_keywords = []
				parts = []
				while target =~ pattern do
					parts << $~.pre_match
					parts << $~.to_s
					hit_keywords << $~.to_s
					target = $~.post_match
				end
				
				parts << target
				
				hits[i] << ContentSearchHit.new(hit_keywords, parts, length) unless parts.size <= 1
				
				
				# And検索処理
				buf = []
				hits[i].each do |hit|
					buf += hit.keywords
				end
				buf.uniq!
				hits[i].clear unless (keywords - buf).empty?
=begin
				keywords.each do |keyword|
					target = entry.content
					parts = []
					while target =~ patterns[keyword] do
						parts << $~.pre_match
						parts << $~.to_s
						target = $~.post_match
					end
					
					parts << target
					
					hits[i] << ContentSearchHit.new(keyword, parts)
				end
=end
			end
			
			list = []
			entries.each_index do |i|
				score = 0
				hits[i].each{|x| score += x.score}
				list << [entries[i], hits[i], score]
			end
			
			# and検索
			#list = list.find_all do |entry, hits, score|
			#	keywords.all? do |keyword|
			#		hits.find{|x| x.keyword == keyword}
			#	end
			#end
			
			list.delete_if{|x| x[2] == 0}
			
			# スコアソート
			list.sort!{|a, b| b[2] <=> a[2]}
			
			
			
			return list
		end
		

	end
	
	
	# テスト用（実際のファイルアクセスを行わない）
	class RepositoryStub < Repository
		attr_accessor :entries
		
		def initialize(dir_path)
			super
			@entries = {}
		end
	
		def lock
			@in_transaction = true
			yield(self)
			@in_transaction = false
		end
		
		def check_valid
			nil
		end
		
		def get_entry_ids
			@entries.keys
		end
		
		def load_entry(id)
			@entries[id]
		end
		
		def save_entry(entry)
			check_transaction
			@entries[entry.id] = entry
		end
		
		def delete_entry(id)
			check_transaction
			@entries.delete(id)
		end
		
		def load_messages
			[]
		end
		
		def add_message
			check_transaction
		end
		
		def delete_messages
			check_transaction
		end
		
		def read_mark_messages
			check_transaction
		end
		
		def get_feed_ids
			[]
		end
		
		def load_access_data
			{'counts' => {}, 'referers' => {}}
		end

		def record_access(entry_id, referer_url)
			check_transaction
		end
		
		def load_referer_table
			[]
		end
		
		def save_referer_table(text)
			check_transaction
		end


		
	end
	

	
	class SearchHit
		attr_reader :keywords
	end
	
	class TitleSearchHit < SearchHit
		def initialize(keywords, parts, content_length)
			@keywords = keywords
			@parts = parts
			@content_length = content_length
		end
		def score
			(@parts.size * 500 / @content_length)
		end
		
		def to_s
			str = "タイトルに一致："
			i = 0
			
			while @parts[i] do
				str << Util.escape_html(@parts[i])
				if @parts[i+1] then
					str << '<strong>' << Util.escape_html(@parts[i+1]) << '</strong>'
					i += 2
				else
					break
				end
			end
				
			
			return Amrita::SanitizedString.new(str)
		end
	end
	
	class TagSearchHit < SearchHit
		def initialize(keywords, tags)
			@keywords = keywords
			@tags = tags
		end
		def score
			@tags.uniq.size * 5
		end
		
		def to_s
			"タグに一致：#{@tags.join(' / ')}"
		end
	end

	
	class ContentSearchHit < SearchHit
		SUMMARIZED_LENGTH = 300
		PREPART_SUMMARIZED_LENGTH = 60
		def initialize(keywords, parts, content_length)
			@keywords = keywords
			@parts = parts
			@content_length = content_length
		end

		def score
			(@parts.size * 1000 / @content_length)
		end
		
		def to_s
			str = "本文に一致："
			
			# 省略
			start = PREPART_SUMMARIZED_LENGTH * -1
			@parts[0] = '...' + @parts[0].each_char[start, PREPART_SUMMARIZED_LENGTH].join if @parts[0].jlength > PREPART_SUMMARIZED_LENGTH
			

			i = 0
			while @parts[i] do
				str << Util.escape_html(@parts[i])
				if @parts[i+1] then
					str << '<strong>' << Util.escape_html(@parts[i+1]) << '</strong>'
					i += 2
				else
					break
				end
			end
				
			# 要約
			if str.jlength > SUMMARIZED_LENGTH then
				str = str.each_char[0, SUMMARIZED_LENGTH].join + '...'
			end
			
			return Amrita::SanitizedString.new(str)
		end
	end
	
	
end



