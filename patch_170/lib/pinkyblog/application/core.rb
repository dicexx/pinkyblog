# encoding: utf-8

require 'cgisup'
require 'time'
require 'digest/md5'
require 'amrita/template'
require 'pathname'
require 'anjson'
require 'jcode'
require 'image_size'
require 'fileutils'
require 'simplemail' 
require 'kconv'
#require 'atom/service'

require 'pinkyblog/const'
require 'pinkyblog/config'
require 'pinkyblog/util'
require 'pinkyblog/repository'
require 'pinkyblog/view-context'
require 'pinkyblog/module-handler'
require 'pinkyblog/screen'
require 'pinkyblog/request'


module PinkyBlog
	# モジュールやレポジトリ、設定ファイルなどを統括するクラス
	class Application
		attr_reader :config, :repository, :module_handler
		
		# インスタンス生成＋モジュールと設定ファイルのロード
		def self.load(config = Config.new)
			app = self.new(config)
			app.load_config(app.repository.blog_config_file_path)
			app.load_config(app.repository.post_limit_file_path)
			app.load_config(app.repository.mail_notification_config_file_path)
			app.load_modules
			return app
		end
		
		def initialize(config = Config.new)
			@config = config
			@repository = Repository.new(@config.data_dir_path)
			@module_handler = ModuleHandler.new(@config)
			@master_session_ids = []
		end
		
		def load_modules
			@module_handler.load(@config)
		end
		
		def load_config(file_path)
			@config.extend_json(file_path)
		end
		
		def generate_session_id
      md5 = Digest::MD5::new
      now = Time::now
      md5.update(now.to_s)
      md5.update(String(now.usec))
      md5.update(String(rand(0)))
      md5.update(String($$))
      md5.update('pinky')
      return md5.hexdigest
		end
		
		
		def set_new_session_id
			new_id = generate_session_id
			@master_session_ids << new_id
			json = AnJSON.dump({'master_session_ids' => @master_session_ids})
			Util.write_text(@config.data_dir_path + '_session_data.json', json, File::WRONLY|File::CREAT|File::TRUNC, 0600)
			return new_id
		end
		
		def delete_session_id(id)
			@master_session_ids.delete(id)
			json = AnJSON.dump({'master_session_ids' => @master_session_ids})
			Util.write_text(@config.data_dir_path + '_session_data.json', json, File::WRONLY|File::CREAT|File::TRUNC, 0600)
			return nil
		end
		
		def load_session_id
			json = Util.read_text(@config.data_dir_path + '_session_data.json') || Util.read_text('./_session_data')
			if json then
				data = AnJSON.parse(json)
				@master_session_ids = data['master_session_ids']
			else
				@master_session_ids = []
			end
			return nil
		end
		

		def generate_news_feeds(context)
				# キャッシュからニュースフィードを生成してしまうのを防ぐ
				@repository.clear_cache
				
				req = context.request
				dir_path = @config.feed_dir_path
				
				path = @config.lib_dir_path + 'pinkyblog/template/atom.xml'
				tmpl = Amrita::TemplateText.new(path.read.untaint)
				tmpl.amrita_id = 'amrita_src'
				tmpl.xml = true
				
				feed_ids = @repository.get_feed_ids('created', 'modified', 'comment')
				entries = @repository.load_all_entries
				modified_entries = entries.sort{|a, b| b.last_modified <=> a.last_modified}.slice(0, 20)
				created_entries = entries.sort{|a, b| b.created <=> a.created}.slice(0, 20)
				
	
				model = {}
				model[:title] = @config.site_title
				model[:generator] = "PinkyBlog"
				model[:alternate_link] = context.absolute_uri_to('/')
				model[:author] = {:name => @config.writer_name}
	
				# created
				model[:id] = "urn:uuid:" + feed_ids['created']
				model[:self_link] = context.get_feed_url('created.xml')
				if created_entries.empty? then
					model[:updated] = Time.now.xmlschema
				else
					model[:updated] = created_entries.first.created.xmlschema
					model[:entries] = created_entries.map{|x| entry_to_atom_model(context, x)}
				end
				
				created_xml = ""
				tmpl.expand(created_xml, model)
	
				# modified
				model[:id] = "urn:uuid:" + feed_ids['modified']
				model[:self_link] = context.get_feed_url('modified.xml')
				if modified_entries.empty? then
					model[:updated] = Time.now.xmlschema
				else
					model[:updated] = modified_entries.first.created.xmlschema
					model[:entries] = modified_entries.map{|x| entry_to_atom_model(context, x)}
				end
				modified_xml = ""
				tmpl.expand(modified_xml, model)
				
				comment_data = [] # [[entry, comment], [entry, comment], ...]
				entries.each do |entry|
					entry.existing_comments.each{|x| comment_data << [entry, x]}
				end
				comment_data.sort!{|a,b| b[1].time <=> a[1].time}
				comment_data.slice!(0, 20)
				
				# comment
				model[:id] = "urn:uuid:" + feed_ids['comment']
				model[:self_link] = context.get_feed_url('comment.xml')
				unless comment_data.empty? then
					model[:updated] = comment_data.first[1].time.xmlschema 
					model[:entries] = comment_data.map do |entry, comment|
						comment_to_atom_model(context, entry, comment)
					end
				end
				comment_xml = ""
				tmpl.expand(comment_xml, model)


				open(dir_path + 'created.xml', 'w'){|f| f.write(created_xml)}
				open(dir_path + 'modified.xml', 'w'){|f| f.write(modified_xml)}
				open(dir_path + 'comment.xml', 'w'){|f| f.write(comment_xml)}
				
				return true
		end
		
		def entry_to_atom_model(context, entry)
			model = {}
			model[:title] = entry.title
			model[:id] = "urn:uuid:#{entry.uuid}"
			model[:updated] = entry.last_modified.xmlschema
			model[:published] = entry.created.xmlschema

			html = ""
			images = load_attached_images(entry.id)
			if not images.empty? and entry.attached_image_display != ID::INVISIBLE then
				html << "<ul>"
				images.each do |img|
					href = context.absolute_uri_to("/entries/#{entry.id}/attached/#{img.name}")
					html << %Q|<li><a href="#{href}">添付画像：#{Util.escape_html(img.name)}（#{img.info}）</a></li>|
				end
				html << "</ul>"
			end
			html << module_handler.translate(entry.format, entry.content)
			model[:content] = Util.escape_html(html)
			
			model[:alternate_link] = context.absolute_uri_to("entries/#{entry.id}")
			model[:categories] = entry.normal_tags.map{|x| {:term => x}}
			return model
		end
		
		def comment_to_atom_model(context, entry, comment)
			model = {}
			model[:title] = comment.writer || '（無記名）'
			model[:id] = "urn:uuid:#{comment.uuid}"
			model[:updated] = comment.time
			model[:published] = comment.time
			model[:summary] = comment.content
			model[:alternate_link] = context.get_cgi_url("entries/#{entry.id}", nil, 'COMMENT')
			return model
		end

		
		def generate_snapshot(req)
			
			root = Pathname.new("./snapshot/")
			targets = req.get_param_array('targets')
			config = @config.dup

			menu = Menu.new
			SNAPSHOT_MENU_KEYS.each do |key|
				if key.in?(SNAPSHOT_REQUIRED_MENU_KEYS) or req.get_param("#{key}_visible") then
					menu.items << MenuItem.create(req.get_param_string("#{key}_caption"), DEFAULT_MENU_COMMAND_TABLE[key], [])
				end
			end
			config.menu = menu
			
			FileUtils.mkdir_p(root)
			opts = {:module_handler => @module_handler}
			context = ViewContext.new(config, req, false)
			
			
			context.snapshot_path = Pathname.new('./index.html')
			context.path_refered_by_menu = '/'
			get_top_screen(context, opts).snapshot(root)
			
			context.snapshot_path = Pathname.new('./files/about.html')
			context.path_refered_by_menu = '/about'
			get_about_screen(context, opts).snapshot(root)

			entries = @repository.load_all_entries
			
			case req.get_param('span')
			when /^tag\-(.+)$/
				tag = Util.decode_base64url($1)
				entries = entries.find_all{|x| x.visible_tags.include?(tag)}
			when /^month\-(\d+)\-(\d+)$/
				year, month = $1.to_i, $2.to_i
				entries = entries.find_all{|x| x.created.year == year and x.created.month == month}
			when 'all'
			else
				raise PinkyBlog::Error, "unknown span - #{req.get_param('span')}"
			end
			
			if entries.size == 0 then
				raise PinkyBlog::Error, "no snapshot targets (entries.size = 0)"
			end	

			opts[:start] = 0
			page = 1
			until opts[:start] > entries.size do
				context.snapshot_path = Pathname.new('./files/') + Util.page_number_to_file_name('entries', page)
				context.path_refered_by_menu = '/entries'
				 
				screen = get_entry_list_screen(context, opts, entries)
				screen.snapshot(root)
				opts[:start] += screen.page_length
				page += 1
			end

			context.path_refered_by_menu = nil

			entries.each do |entry|
				context.snapshot_path = Pathname.new("./files/entries/#{entry.id}.html")
				get_entry_screen(context, opts, entry.id).snapshot(root)
			end
		
			load_attached_image_table(entries.map{|x| x.id}).each_pair do |entry_id, images|
				images.each do |img|
					context.snapshot_path = Pathname.new("./files/entries/#{entry_id}/attached/#{img.name}.html")
					get_attached_image_screen(context, opts, entry_id, img.name).snapshot(root)
				end
			end

			
			
			# CSSテンプレート＆リソースをコピー
			if req.get_param('include_cdp') then
				copy_dir_for_snapshot(@config.cdp_dir_path, root + 'files/csstemplate/')
			end
			if req.get_param('include_res') then
				copy_dir_for_snapshot(@config.res_dir_path, root + 'files/res/')
			end
		end
		
		# src_root配下のファイル全てをdest_rootにコピー
		# FileUtils.cp_rでは無限ループを起こすことがあるため、別メソッドを用意した
		def copy_dir_for_snapshot(src_root, dest_root)
			src_root = Pathname.new(src_root)
			Dir.mkdir(dest_root) unless dest_root.exist?
			
			srcs = Pathname.glob(src_root + '**/*')
			dest_table = {}
			
			srcs.each do |src|
				src.untaint
				dest_table[src] = dest = dest_root + src.relative_path_from(src_root)
				if src.directory? then
					FileUtils.mkdir(dest) unless dest.exist?
				end
			end
			
			srcs.each do |src|
				if src.file? then
					FileUtils.cp(src, dest_table[src])
				end
			end
			
		end
		private :copy_dir_for_snapshot

		
		
		# sendmailコマンドで通知メールを送信する
		def mail_notification(subject, body)
			if @config.sendmail_path and not @config.mail_notification_to_addresses.empty? then
				mail = SimpleMail.new(@config.sendmail_path + ' -t')
				to = @config.mail_notification_to_addresses.join(', ')
				mail.to = to
				mail.from = to
				mail.subject = Util.encode_for_mail_header("#{subject} - #{@config.site_title}")
				mail.text = Util.encode_to_jis(body + "\n\n#{'-' * 16}\n#{@config.site_title} 通知メール")
				mail.headers['Content-Type'] = 'text/plain; charset=ISO-2022-JP'
				
				code = mail.send
				
				return code
			else
				return nil
			end
		end

		
		
		


		# Rack::Requestを受けて、ScreenやRedirectorを返す
		def request(req)
			# キャッシュクリア
			@repository.clear_cache
		
		
			# 管理者としてログイン済みかどうかをチェック
			load_session_id
			
			opts = {:cookie_data => {}, :module_handler => @module_handler}

			ids = req.multiple_cookies['session_id'] || []
			if (found_id = ids.find{|x| @master_session_ids.include?(x)}) then
				context = ViewContext.new(@config, req, true)
				exp = (@config.auto_login? ? (Time.now + MASTER_SESSION_TIME_LIMIT) : nil)
				opts[:cookie_data]['session_id'] = {:value => found_id, :expires => exp, :path => context.cookie_path}
			else
				context = ViewContext.new(@config, req, false)
			end
			

			# HTMLカスタマイズの設定を適用
			opts[:custom_html] = {}
			
			dir_path = @repository.custom_html_dir_path
			if dir_path.exist? then
				[:head, :kizi_foot, :body_foot].each do |id|
					opts[:custom_html][id] = Util.read_text(dir_path + "#{id.to_s}.html")
				end
			end
			
			
			# logout値があればログアウト処理
			if req.params['logout'] then
				if context.master_mode? then
					opts[:cookie_data]['session_id'] = {:value => '', :expires => Time.now - 1, :path => context.cookie_path}
					opts[:message] = "ログアウトしました。"
					opts[:path] = '/'
					delete_session_id(req.cookies['session_id'])
					return Redirector.new(context, opts)
				else
					opts[:error_message] = "あなたは管理モードからのログアウトを要求しましたが、ログアウトはすでに完了しています。"
					opts[:http_status] = HTTP_CONFLICT
					return ErrorScreen.new(context, opts)
				end
			end
			
			
			
			if req.path_info == '/post' then
				request_post(context, opts)
			else
				request_get(req.path_info, context, opts)
			end
			
		end
		
		def request_get(path, context, opts)
			master_mode = context.master_mode?
			req = context.request
		
			path_items = path.split('/')
			path_items.delete_if{|x| x.empty?}
			case path_items[0]
			#when 'app'
			#	request_app(context, opts)
			
			when 'script_error'
				
			when 'version', 'system'
				SystemInformationScreen.new(context, opts)
				

			when 'entries'
				entry_id = path_items[1]
				if entry_id and entry_id.include?(';') then
					entry_ids = entry_id.split(';')
					get_entries_screen(context, opts, entry_ids)
				elsif entry_id then
				
					case path_items[2]
					when 'edit', 'edit_form'
						get_entry_edit_form_screen(context, opts, entry_id)
					when 'attached'
						image_name = path_items[3]
						image_name.untaint
						get_attached_image_screen(context, opts, entry_id, image_name)
						
					when 'comments'
						comment_index = path_items[3].to_i - 1
						case path_items[4]
						when 'edit_form'
							get_comment_edit_form_screen(context, opts, entry_id, comment_index)
						end

					when nil
						# 個別エントリ表示
						
						ids = @repository.get_entry_ids
						unless ids.include?(entry_id) then
							opts[:http_status] = HTTP_NOT_FOUND
							opts[:error_message] = "指定されたID #{Util.escape_html(entry_id)} の記事は見つかりませんでした。"
							return ErrorScreen.new(context, opts)
						end

						# 管理モードの時にはアクセス記録に数えない
						unless master_mode then
							ex_pattern = /#{Regexp.escape(req.script_name.to_s)}/i
							if req.referer.to_s.empty? or req.referer.to_s =~ ex_pattern then
								# サイト内からのリンクorリファラ不明のリンク
								@repository.lock{
									@repository.record_access(entry_id, nil, req.env['REMOTE_ADDR'])
								}
							else
								@repository.lock{
									@repository.record_access(entry_id, req.referer, req.env['REMOTE_ADDR'])
								}
							end
						end

						return get_entry_screen(context, opts, entry_id)
					end
					
				else
					return get_entry_list_screen(context, opts)
				end
				
			when 'login', 'login_form'
				return LoginFormScreen.new(context, opts)

			when 'search'

				opts[:keywords] = req.get_param_str('keyword').split(/\s|　/).map{|x| CGI.unescape(x)}
				opts[:hit_list] = []
				unless opts[:keywords].empty? then
					opts[:hit_list] = @repository.search(opts[:keywords], master_mode)
				end
				
				return SearchScreen.new(context, opts)

			when 'recent'
				return get_recent_screen(context, opts)

			when 'about'
				return get_about_screen(context, opts)

			when 'news_feed'
				return NewsFeedScreen.new(context, opts)


				
			when 'master_menu'
				return ForbiddenScreen.new(context, opts) unless master_mode
				
				case path_items[1]
				when 'entry_add_form'
					@repository.lock{
						list = []
						load_temporary_attached_images.each do |img|
							list << @config.attached_dir_path + "__temp_#{img.name}"
						end
							
						begin
							list.each do |path|
								path.delete
							end
						rescue Errno::EACCES
							# なぜかPermission Deniedで削除に失敗することがある（理由不明）
							opts[:message] = '一時保存されている画像ファイル（前回アップロードされたもの）の削除に失敗したため、はじめから画像が添付された状態になっています。手動で画像の削除を行ってください。'
						end
					}
					opts[:tag_list] = @repository.get_tag_list([], true)
					opts[:attached_images] = load_temporary_attached_images

					return EntryAddScreen.new(context, opts)
					
				when 'message_list'
					@repository.lock{
						opts[:messages] = @repository.load_messages
						@repository.read_mark_messages
					}
					return MessageListScreen.new(context, opts)
					
				when 'blog_config'
					return BlogConfigScreen.new(context, opts)
				
				when 'menu_edit_form'
					menu_text = Util.read_text(@config.data_dir_path + 'menu.txt')
					opts[:menu_text] = menu_text
					case path_items[2]
					when 'direct'
						return DirectMenuEditScreen.new(context, opts)
					when 'simple'
						return MenuEditScreen.new(context, opts)
					else
						case @config.menu_type
						when MT::DIRECT
							return DirectMenuEditScreen.new(context, opts)
						when MT::SIMPLE
							return MenuEditScreen.new(context, opts)
						end
					end

				when 'post_limit'
					return PostLimitScreen.new(context, opts)
					
				when 'mail_notification_config'
					return MailNotificationConfigScreen.new(context, opts)

				when 'html_customize'
					return HTMLCustomizeScreen.new(context, opts)
		
				when 'referer_config'
					opts[:table] = @repository.load_referer_table
					text = Util.read_text(@repository.referer_table_file_path)
					if text then
						md = MD.parse(text)
						track = md.find_type('PinkyBlog/RefererTable')
						opts[:table_text] = track.body
					else
						opts[:table_text] = ''
					end
					return RefererConfigScreen.new(context, opts)
					
				when 'entry_manager'
					opts[:entries] = @repository.load_all_entries(true)
					opts[:attached_image_table] = load_attached_image_table(opts[:entries].map{|x| x.id})
					opts[:access_record] = @repository.load_access_data
					opts[:file_data] = {}
					opts[:file_data][:size] = {}
					opts[:entries].each do |entry|
						path = repository.get_entry_file_path(entry.id)
						opts[:file_data][:size][entry.id] = path.size
					end
					return EntryManagerScreen.new(context, opts)
				when 'snapshot'
					case path_items[2]
					when 'result'
						size = 0
						number = 0
						Pathname.glob('snapshot/**/*').each do |path|
							if path.untaint.file? then
								size += path.size
								number += 1
							end
						end
						
						opts[:total_file_size] = Util.size_to_kb(size)
						opts[:total_file_number] = number
						opts[:time] = context.request.get_param('time')
						return SnapshotResultScreen.new(context, opts)
					else
						opts[:entries] = @repository.load_all_entries
						return SnapshotScreen.new(context, opts)
					end
				when 'import'
					begin
						require 'zlib'
						opts[:zlib_installed] = true
					rescue Exception
						opts[:zlib_installed] = false
					end
					return ImportFormScreen.new(context, opts)
					
				when 'export'
					case path_items[2]
					when 'result'
						opts[:entry_number] = context.request.get_param('entry_number')
						opts[:file_name] = context.request.get_param('file_name')
						
						path = @config.res_dir_path + 'temp/' + Util.encode_file_name(context.request.get_param('file_name')).untaint
						opts[:file_size] = Util.size_to_kb(path.size)
						opts[:time] = context.request.get_param('time')
						return ExportResultScreen.new(context, opts)
					when 'mt-compatible'
						return ExportByMTCompatibleScreen.new(context, opts)
					when 'pblog'
						begin
							require 'zlib'
							opts[:zlib_installed] = true
						rescue Exception
							opts[:zlib_installed] = false
						end
						
						return ExportByPblogScreen.new(context, opts)
					else
						return ExportFormatSelectScreen.new(context, opts)
					end
					
					
	
				when 'system_monitor'
					if @config.demo? then
						return redirect(context, opts, '/master_menu', '動作サンプルではシステムモニターは表示できません。')
					end
				
					case path_items[2]
					when 'parity_check'
						opts[:result_data] = []
						ids = @repository.get_entry_ids.sort
						parity_data = @repository.load_parity
						
						ids.each do |id|
							path = @repository.get_entry_file_path(id)
							entry = @repository.load_entry(id)
							unless parity_data['entry'][id] then
								parity_data['entry'][id] = Util.digest_file(path)
							end
							
							if parity_data['entry'][id] == Util.digest_file(path) then
								result = 'OK'
							else
								result = Amrita::SanitizedString.new('<em>異常あり</em>')
							end
							
						
							opts[:result_data] << {:file_name => path.basename, :result => result, :title => entry.title_caption}
						end
						
						@repository.save_parity(parity_data)
						
						return ParityCheckScreen.new(context, opts)
					when 'tree'
						
						if (path = @config.send(path_items[3])) then
							return FileTreeScreen.new(context, opts.merge(:root => path))
						end
					
					else
					
					
						opts[:time_data] = []
						ids = @repository.get_entry_ids
						@repository.clear_cache
						opts[:time_data] << ["全記事IDの取得", Benchmark.realtime{ @repository.get_entry_ids }]
						@repository.clear_cache
						opts[:time_data] << ['1記事読み込み', Benchmark.realtime{ @repository.load_entry('welcome') }]
						@repository.clear_cache
						entries = nil
						opts[:time_data] << ["全#{ids.size}記事読み込み", Benchmark.realtime{ entries = @repository.load_all_entries }]
						opts[:time_data] << ["ひとことメッセージデータファイル読み込み", Benchmark.realtime{ @repository.load_messages }]
						opts[:time_data] << ["アクセス記録ファイル読み込み", Benchmark.realtime{ @repository.load_access_data }]
						opts[:time_data] << ["HTML生成", Benchmark.realtime{
							FormatGuideScreen.new(context, opts).to_rack_response
						}]
						#opts[:times]["HTML生成:記事一覧"] = Benchmark.realtime{
						#	EntryListScreen.new(context, opts.merge(:entries => entries)).to_rack_response
						#}
		
						
						return SystemMonitorScreen.new(context, opts)
					end

				
				
				#when 'export_form'
				#	return ExportFormScreen.new(context, opts)
				else
					opts[:notifications] = []
					
					
					opts[:messages] = @repository.load_messages
					unread = opts[:messages].find_all{|x| !(x.read?)}.size
					if unread > 0 then
						opts[:notifications] << "新しいひとことメッセージが#{unread}件届いています。"
					end
				
					return MasterMenuScreen.new(context, opts)
				end
			when 'format_guide'
				if path_items[1] then
					return FormatDetailScreen.new(context, opts)
				else
					return FormatGuideScreen.new(context, opts)
				end
				

			when 'top'
				get_top_screen(context, opts)
			when nil
				request_get(@config.menu.items.first.path, context, opts)
			else
				opts[:error_message] = "パス #{Util.escape_html(req.path_info)} を解釈できませんでした。"
				return ErrorScreen.new(context, opts)
			end
		end
		
		def get_top_screen(context, opts, recent_entries = @repository.load_recent_entries(5, context.master_mode?))
			opts[:welcome_entry] = @repository.load_entry('welcome') || StaticEntry.new('welcome')
			opts[:recent_entries] = recent_entries
			opts[:attached_images] = load_attached_images('welcome')

			return TopScreen.new(context, opts)
		end
		
		def get_about_screen(context, opts)
			opts[:about_blog_entry] = @repository.load_entry('about_blog') || StaticEntry.new('about_blog')
			opts[:about_writer_entry] = @repository.load_entry('about_writer') || StaticEntry.new('about_writer')
			opts[:attached_image_table] = load_attached_image_table(['about_blog', 'about_writer'])
			return AboutScreen.new(context, opts)
		end
		
		def get_attached_image_screen(context, opts, entry_id, image_name)
			opts[:entry] = @repository.load_entry(entry_id)
			
			images = load_attached_images(entry_id)
			img = images.find{|x| x.name == image_name}
			if img then
				opts[:image] = img
				return AttachedImageScreen.new(context, opts)
			else
				return error(context, opts, "エントリID #{entry_id} に対応する画像 #{image_name} が見つかりませんでした。")
			end
		end

		
		def get_entry_screen(context, opts, entry_id)
			opts[:entry] = @repository.load_entry(entry_id)
			opts[:referer_list] = @repository.get_referer_list(entry_id)
			opts[:ex_footer_visible] = true
			opts[:attached_images] = load_attached_images(entry_id)
			return EntryScreen.new(context, opts)
		end
		
		def get_entries_screen(context, opts, entry_ids)
			opts[:entries] = []
			opts[:attached_image_table] = {}
			entry_ids.each do |id|
				opts[:entries] << @repository.load_entry(id)
			end
			opts[:attached_image_table] = load_attached_image_table(entry_ids)
			opts[:title] = @config.menu.get_current_item(context).caption
			return EntriesScreen.new(context, opts)
		end


		
		def get_entry_edit_form_screen(context, opts, entry_id)
			# エントリ編集
			if context.master_mode? then
				opts[:entry] = @repository.load_entry(entry_id)
				opts[:entry] ||= (Util.static_entry_id? ? StaticEntry.new(entry_id) : BasicEntry.new(entry_id))
				opts[:tag_list] = @repository.get_tag_list([], true)
				opts[:attached_images] = load_attached_images(entry_id)
				
				return EntryEditScreen.new(context, opts)
			else
				return ForbiddenScreen.new(context, opts)
			end
		end

		def get_comment_edit_form_screen(context, opts, entry_id, comment_index)
			opts[:entry] = @repository.load_entry(entry_id)
			opts[:entry] ||= (Util.static_entry_id? ? StaticEntry.new(entry_id) : BasicEntry.new(entry_id))
			opts[:comment_index] = comment_index
			
#			if context.request.get_param('view') == 'section' then
#				return SectionResponse.new(context, opts.merge(:screen_class => :CommentEditScreen))
#			else
				return CommentEditScreen.new(context, opts)
#			end
			
		end
		


		def get_recent_screen(context, opts)
			entries = @repository.load_all_entries(context.master_mode?)
			opts[:entries] = entries
			opts[:attached_image_table] = load_attached_image_table(entries.map{|x| x.id})

			if context.request.get_param('number') then
				opts[:page_length] = context.request.get_param('number').to_i
			end
			
			req_tags = context.request.tags
			unless req_tags.empty? then
				opts[:entries] = entries.find_all{|x| (req_tags - x.tags).empty?}
			end

			
			return RecentScreen.new(context, opts)
		end
		
		def get_entry_list_screen(context, opts, entries = @repository.load_all_entries(context.master_mode?))
			opts[:entries] = entries
			opts[:tag_list] = @repository.get_tag_list(context.request.tags, context.master_mode?)
			opts[:access_counts] = @repository.load_access_data['counts']

			return EntryListScreen.new(context, opts)
		end

		
		
		def load_attached_images(entry_id)
			if @config.attached_dir_path.readable? then
				search_images_in_list(entry_id, @config.attached_dir_path.children)
			else
				[]
			end
		end
		
		def load_temporary_attached_images
			load_attached_images('__temp')
		end
		
		def load_attached_image_table(entry_ids)
			if @config.attached_dir_path.readable? then
				paths = @config.attached_dir_path.children
				re = {}
				entry_ids.each do |id|
					re[id] = search_images_in_list(id, paths)
				end
				
				re
			else
				Hash.new([])
			end
		end

		

		
		
		private
		
		def search_images_in_list(entry_id, file_paths)
			re = []
			pattern = /#{Regexp.escape(entry_id)}_(.+\.(?:png|jpeg|jpg|gif))$/i
			file_paths.each do |path|
				if path.untaint.to_s =~ pattern then
					img_name = $1
					w, h = Util.get_image_size(path)
					re << Image.new(img_name, w, h, path.size)
				end
			end

			re.sort!{|a, b| a.name <=> b.name}
			re
		end
		
		def edit_blog_config
			data = @repository.load_blog_config
			yield(data)
			@repository.save_blog_config(data)
			
			self.load_config(@repository.blog_config_file_path) # reload for WEBrick
			return self
		end
		
		def error(context, opts, msg)
			opts[:error_message] = msg
			ErrorScreen.new(context, opts)
		end
		
		def redirect(context, opts, path, msg, query = nil)
			opts[:path] = path
			opts[:query] = query
			opts[:message] = msg
			return Redirector.new(context, opts)
		end
		
		
		def request_post(context, opts)
			req = context.request
			master_mode = context.master_mode?
			error_proc = Proc.new{|msg|
				error(context, opts, msg)
			}
			
			forbidden_proc = Proc.new{
				ForbiddenScreen.new(context, opts)
			}
			
			redirection = Proc.new{|path, msg|
				opts[:path] = path
				opts[:message] = msg
				Redirector.new(context, opts)
			}
			
			action = req.get_param_string('action')
			case action
			when 'change_cdp'
				if req.has_key?('cdp_name') then
					cookie = CGI::Cookie.new('cdp_name', req.get_param('cdp_name'))
					opts[:cookies] << cookie
					return redirection.call('', "テンプレートを#{req.get_param('cdp_name')}に変更しました。")
				else
					cookie = CGI::Cookie.new('cdp_name', '')
					cookie.expires = Time.now - 30
					opts[:cookies] << cookie
					return redirection.call('', "テンプレートを変更しました。")
				end
			when 'master_login'
				post_master_password(context, opts)				
			when 'snapshot'
				post_snapshot(context, opts)
				
			when 'edit_entry'
				post_entry(context, opts)
			
			when 'comment', 'edit_comment'
				content = req.get_param_str('content')
				password = req.get_param('password')
				
				if content.empty? then
					return error_proc.call("コメント本文に何も入力されていません。")
				end

				if content.jlength > @config.real_comment_length_limit then
					return error_proc.call("コメントが長すぎるため投稿できませんでした。（#{content.jlength} 文字 / #{@config.real_comment_length_limit} 文字）")
				end
				
				if @config.commentator_name_required? and not req.get_param('name') then
					return error_proc.call("名前を記入してください。")
				end
				
				if @config.commentator_address_required? and not req.get_param('address') then
					return error_proc.call("メールアドレスを記入してください。")
				end
				
				if @config.check_spam(content) then
					return PostBlockScreen.new(context, opts)
				end
				
				
				case action
				when 'comment'
					if password and not Util.validate_password(password) then
						return error(context, opts, "パスワードは半角英数、#{Util::PASSWORD_RANGE.first}～#{Util::PASSWORD_RANGE.last}文字で入力してください。")
					end
					
					entry = nil
					@repository.lock{
						entry = @repository.load_entry(req.get_param('entry_id'))
						@repository.comment_to_entry(entry.id, req.get_param('name'), content, req.get_param('address'), password)
					}
					
					# メール通知
					uri = context.absolute_uri_to("/entries/#{entry.id}")
					mail_body = "記事「#{entry.title}」に、以下の内容でコメントが投稿されました。\r\n\r\n"
					mail_body << "投稿者名: #{req.get_param('name')}\r\n"
					mail_body << "投稿者メールアドレス: #{req.get_param('address')}\r\n"
					mail_body << "本文:\r\n#{content}\r\n\r\n詳しくは以下の記事URLを参照してください。\r\n#{uri}"
					mail_notification('記事へのコメント投稿通知', mail_body)
					
					msg = "コメントの投稿に成功しました。ありがとうございます。"

				when 'edit_comment'
					@repository.lock{
						entry = @repository.load_entry(req.get_param('entry_id'))
						comment_index = req.get_param('comment_index')
						
						unless comment_index then
							return error(context, opts, 'comment_index の値が不正です。')
						end
						
						comment = entry.comments[comment_index.to_i]
						
						unless comment then
							return error(context, opts, '指定した番号のコメントが存在しません。')
						end
						
						if context.master_mode? or (password and Digest::SHA1.hexdigest(password) == comment.password_sha) then
							comment.writer = req.get_param('name')
							comment.mail_address = req.get_param('address')
							comment.content = content
							comment.edited_number += 1
							@repository.save_entry(entry)
							msg = "コメント#{comment_index.to_i + 1}番の編集を完了しました。"
							
						else
							return error(context, opts, "あなたの入力したパスワードが、コメント投稿時のパスワードと違うと判定されました。")
						end
					}
				end
				

				
				
				# コメント欄の名前とアドレスをCookieで記憶
				exp = Time.now + 60*60*24*30
				opts[:cookie_data]['default_name'] = {:value => req.get_param_str('name'), :path => context.cookie_path, :expires => exp}
				opts[:cookie_data]['default_address'] = {:value => req.get_param_str('address'), :path => context.cookie_path, :expires => exp}
				
				generate_news_feeds(context)
				
				return redirect(context, opts, "entries/#{req.get_param('entry_id')}", msg)
				
			when 'delete_comment'
				entry_id = req.get_param('entry_id')
				index = req.get_param('comment_index')
				password = req.get_param('password')

				unless index then
					return error(context, opts, 'comment_index の値が不正です。')
				end
				index = index.to_i
				
				@repository.lock{
					entry = @repository.load_entry(entry_id)
					if context.master_mode? or (password and Digest::SHA1.hexdigest(password) == entry.comments[index].password_sha) then
						entry.comments[index].delete
						@repository.save_entry(entry)
						return redirect(context, opts, "entries/#{req.get_param('entry_id')}", "#{index + 1}番のコメントを削除しました。")
					else
						return error(context, opts, "あなたの入力したパスワードが、コメント投稿時のパスワードと違うと判定されました。")
					end
				}

			when 'message'
				return post_message(context, opts)


			when 'blog_config'
				return redirection.call("master_menu/blog_config", '動作サンプルでは、設定の変更はできません。') if context.config.demo?

				if master_mode then
					return redirection.call('master_menu/blog_config', "記入不備：blogの名前を入力してください。") unless req.get_param('site_title')
				
					@repository.lock{
						edit_blog_config do |data|
							data['site_title'] = req.get_param_str('site_title')
							data['writer_name'] = req.get_param_str('writer_name')
							data['writer_address'] = req.get_param('writer_address')
							data['home_url'] = req.get_param('home_url')
							data['headline_title'] = req.get_param('headline_title') if req.get_param('headline_title')
							data['use_comment'] = (req.get_param('use_comment') ? true : false)
							data['commentator_name_required'] = (req.get_param('commentator_name_required') ? true : false)
							data['commentator_address_required'] = (req.get_param('commentator_address_required') ? true : false)
							#data['use_tag'] = (req.get_param('use_tag') ? true : false)
							data['use_image_attaching'] = (req.get_param('use_image_attaching') ? true : false)
							data['message_form_visible'] = (req.get_param('message_form_visible') ? true : false)
							data['message_form_title'] = req.get_param_str('message_form_title')
							data['message_form_guide'] = req.get_param_str('message_form_guide')
							data['default_translator'] = req.get_param_str('default_translator')
							#data['page_changing_type'] = req.get_param('page_changing_type') if req.get_param('page_changing_type')
							data['auto_date_display_type'] = req.get_param('auto_date_display_type') if req.get_param('auto_date_display_type')
							#data['menu_captions'] = {}
							#MENU_KEYS.each do |key|
							#	cgi_key = "menu_caption_of_#{key}"
							#	data['menu_captions'][key] = req.get_param_str(cgi_key) if req.get_param(cgi_key)
							#end
						end
					}
					return redirection.call('master_menu/blog_config', "blog設定を変更しました。")
				else
					return forbidden_proc.call
				end
			when 'menu'
				return redirect(context, opts, "master_menu/menu_edit_form", '動作サンプルでは、メニューの変更はできません。') if context.config.demo?
				return post_menu(context, opts)

			when 'menu_text'
				return redirect(context, opts, "master_menu/menu_edit_form/direct", '動作サンプルでは、メニューの変更はできません。') if context.config.demo?
				return post_menu_text(context, opts)
			when 'post_limit'
				return redirection.call("master_menu/post_limit", '動作サンプルでは、設定の変更はできません。') if context.config.demo?
				if master_mode then
					@repository.lock{
						data = {}
						data['message_length_limit'] = req.get_param_str('message_length_limit')
						data['comment_length_limit'] = req.get_param_str('comment_length_limit')
						data['block_http'] = (req.get_param('block_http') ? true : false)
						data['block_ascii'] = (req.get_param('block_ascii') ? true : false)
						data['ng_words'] = req.get_param_str('ng_word').split(/\r\n|\n/m)
						data['ng_words'].delete_if{|x| x.empty?}
						
						Util.write_text(@repository.post_limit_file_path, AnJSON.pretty_build(data))
						self.load_config(@repository.post_limit_file_path) # reload for webrick
					}
					return redirection.call('master_menu/post_limit', "投稿制限を変更しました。")
				else
					return forbidden_proc.call
				end
				
				
			when 'mail_notification_config'
				if context.config.demo? then
					return redirection.call("master_menu/mail_notification_config", '動作サンプルでは、設定の変更はできません。') 
				elsif master_mode then
					addresses = [req.get_param('to_1'), req.get_param('to_2'), req.get_param('to_3')].compact
					
					if req.get_param('sendmail_path') and addresses.empty? then
						return error(context, opts, '送り先のメールアドレスが入力されていません（メール通知機能を無効にしたいときには、sendmailのパスを空欄にしてください）。')
					else
						@repository.lock{
							data = {}
							data['sendmail_path'] = req.get_param('sendmail_path')
							data['mail_notification_to_addresses'] = addresses
							
							Util.write_text(@repository.mail_notification_config_file_path, AnJSON.pretty_build(data))
							self.load_config(@repository.mail_notification_config_file_path) # reload for webrick
						}
						
						if req.get_param('submit_with_test_mail') then
							msg = 'メール通知設定を変更し、同時にテストメールを送信しました。'
							code = mail_notification('メール通知テスト', 'このメールを受信できていれば、メール通知機能は正常に働いています。')
						else
							msg = 'メール通知設定を変更しました。'
						end
					end
					
					return redirect(context, opts, 'master_menu/mail_notification_config', msg)
				else
					return forbidden_proc.call
				end




			when 'referer_config'
				if master_mode then
					return redirection.call("master_menu/referer_config", '動作サンプルでは、設定の変更はできません。') if context.config.demo?
					@repository.lock{
						@repository.save_referer_table(req.get_param_str('table'))
					}
					return redirection.call('master_menu/referer_config', "リファラ設定を変更しました。")
				else
					return forbidden_proc.call
				end
				
			when 'html_customize'
				post_html_customize(context, opts)
			when 'delete_message'
				return redirection.call("master_menu/message_list", '動作サンプルでは、この機能は使えません。') if context.config.demo?
				if master_mode then
					@repository.lock{
						target_ids = req.get_param('message_ids')
						unless @repository.delete_messages(target_ids) then
							error_proc.call("メッセージファイルの読み書きに失敗しました。")
						end
					}
					return redirection.call('master_menu/message_list', "選択したメッセージをすべて削除しました。")
				else
					return forbidden_proc.call
				end
				
			when 'act_image'
				post_act_image(context, opts)

			when 'act_entries'
				if master_mode then
					ids = req.get_param_array('entry_ids')
				
					if ids.empty? then
						return error_proc.call("記事が一つも選択されていません。")
					end
					
				
					if req.has_key?('submit_delete') then
						opts[:entries] = ids.map{|x| @repository.load_entry(x)}
						opts[:access_record] = @repository.load_access_data
						opts[:file_data] = {}
						opts[:file_data][:size] = {}

						opts[:entries].each do |entry|
							path = repository.get_entry_file_path(entry.id)
							opts[:file_data][:size][entry.id] = path.size
						end
						
						opts[:attached_image_table] = load_attached_image_table(ids)

						return EntryDeleteConfirmationScreen.new(context, opts)
						
					elsif req.has_key?('submit_change_timestamp') then
						opts[:entries] = ids.map{|x| @repository.load_entry(x)}
						return EntryTimestampChangeScreen.new(context, opts)
						
					elsif req.has_key?('submit_delete_ok') then
						return redirection.call("master_menu/entry_manager", '動作サンプルでは、この操作は行えません。') if context.config.demo?
						@repository.lock{
							ids.each do |id|
								@repository.delete_entry(id)
							end
						}
						return redirection.call('master_menu/entry_manager', "選択した記事をtrashディレクトリに移動しました。ファイルの削除は手動で行ってください。")
						
					elsif req.has_key?('submit_delete_ng') then
						return redirection.call("master_menu/entry_manager", '')
						
					elsif req.has_key?('submit_show') then
						return redirection.call("master_menu/entry_manager", '動作サンプルでは、この操作は行えません。') if context.config.demo?
						@repository.lock{
							ids.each do |id|
								entry = @repository.load_entry(id)
								entry.visible = true
								@repository.save_entry(entry)
							end
						}
						return redirection.call('master_menu/entry_manager', "選択した記事を「公開」状態にしました。")
					elsif req.has_key?('submit_hide') then
						return redirection.call("master_menu/entry_manager", '動作サンプルでは、この操作は行えません。') if context.config.demo?
						@repository.lock{
							ids.each do |id|
								entry = @repository.load_entry(id)
								entry.visible = false
								@repository.save_entry(entry)
							end
						}
						return redirection.call('master_menu/entry_manager', "選択した記事を「非公開」状態にしました。")
						
					elsif req.has_key?('submit_delete_all_tag') then
						@repository.lock{
							ids.each do |id|
								entry = @repository.load_entry(id)
								entry.tags.clear
								@repository.save_entry(entry)
							end
						}
						return redirection.call('master_menu/entry_manager', "選択した記事のタグをすべて削除しました。")
					
					elsif req.has_key?('submit_add_tag') || req.has_key?('submit_delete_tag') then
						tags = req.get_param_str('target_tag').split(/\s|　/)
						tags.uniq!
						@repository.lock{
							ids.each do |id|
								entry = @repository.load_entry(id)
								if req.has_key?('submit_add_tag') then
									entry.tags += tags
									entry.tags.uniq!
								elsif req.has_key?('submit_delete_tag') then
									entry.tags -= tags
								end
								
								@repository.save_entry(entry)
							end
						}
						msg = "タグ"
						msg << tags.map{|x| "「#{x}」"}.join
						msg << (req.has_key?('submit_delete_tag') ? "を削除しました。" : "を追加しました。")
						return redirection.call('master_menu/entry_manager', msg)
					end
				else
					return forbidden_proc.call

				end
			when 'change_timestamp'
				post_change_timestamp(context, opts)
			
			when 'export'
				post_export(context, opts)
			when 'import_file'
				post_import_file(context, opts)
			when 'import_list'
				post_import_list(context, opts)
			when ''
				return error(context, opts, "動作の種類（アクション）を指定するためのパラメータが見つかりません。もしもブックマーク（お気に入り）などからこのページに飛んできたのであれば、ここではなくトップページのURLを登録し直してください。")
			else
				return error(context, opts, "「#{req.get_param_str('action')}」は未知のアクション名です。")
			end
		end
		
		def post_master_password(context, opts)
			req = context.request
			if req.get_param('password') == context.config.master_password then

				auto_login = (req.get_param('auto_login') ? true : false)
				unless auto_login == context.config.auto_login then
					@repository.lock{
						data = @repository.load_blog_config		
						data['auto_login'] = auto_login
						@repository.save_blog_config(data)
						
						self.load_config(@repository.blog_config_file_path) # reload for webrick
					}
				end
				
			
				new_id = set_new_session_id
				if context.config.auto_login then
					exp = Time.now + MASTER_SESSION_TIME_LIMIT
				else
					exp = nil
				end
				opts[:cookie_data]['session_id'] = {:value => new_id, :expires => exp, :path => context.cookie_path}
				
				return redirect(context, opts, 'master_menu', "ログインに成功しました。")
			else
				return error(context, opts, "パスワードが違うと判定されました。")
			end
		end
		
		def post_message(context, opts)
			content = context.request.params['content'].to_s

			if content.empty? then
				return error(context, opts, "メッセージ本文が何も入力されていません。")
			end

			if content.jlength > context.config.real_message_length_limit then
				return error(context, opts, "メッセージが長すぎるため投稿できませんでした。（#{content.jlength} 文字 / #{@config.real_message_length_limit} 文字）")
			end
			
			if context.config.check_spam(content) then
				return PostBlockScreen.new(context)
			end

			
			@repository.lock{
				@repository.add_message(content)
			}
			mail_notification('ひとことメッセージ着信通知', "以下の内容でひとことメッセージが届きました。\r\n\r\n本文:\r\n#{content}")
			
			redirect(context, opts, '/', "メッセージの送信に成功しました。ありがとうございます。")
		end
		
		def post_entry(context, opts)
			req = context.request
			entry_id = req.get_param('id')
			if entry_id then
				Util.validate_entry_id(entry_id)
			end
		

			
			if not context.master_mode? then
				return forbidden_proc.call
			elsif req.params.has_key?('submit_preview') or req.params.has_key?('submit_upload_and_preview') then
				# プレビューバックアップ
				body = req.get_param('content')
				if body then
					body.gsub!(/\r\n/, "\n")
					Util.write_text(@repository.preview_backup_file_path, {'id' => entry_id, 'body' => body}.ya2yaml)
				end
			
			
			
			
				# アップロードされた画像の処理
				success_images = []
				existed_images = []
				
				if context.config.demo? then
					opts[:message] = '動作サンプルでは画像のアップロードは行えません。' 
				else
					if req.get_param('submit_upload_and_preview') then
						(1..3).each do |i|
							file_data = req.params["image_file#{i}"]
							if file_data and file_data[:type] and not file_data[:filename].empty? then
								entry_id.untaint if entry_id
								src = Pathname.new(file_data[:filename])
								
								body = file_data[:tempfile].read
								if body.length > 1024 * 1024 * 2 then
									return error(context, opts, "#{Util.escape_html(src.basename)} のサイズが2MBを越えているため、アップロードに失敗しました。")
								elsif not src.extname =~ /\.(?:png|jpeg|jpg|gif)$/i then
									return error(context, opts, "#{Util.escape_html(src.basename)} は画像ファイルではないようです。（添付できる画像は、拡張子が「.png」「.jpeg」「.jpg」「.gif」のもののみです）")
								end
				
								
								# エスケープ
								src_name = Util.encode_file_name(src.basename.to_s)
								
								dest = context.config.attached_dir_path + "#{entry_id || '__temp'}_#{src_name}"
								dest.untaint
								
								if File.exist?(dest) then
									existed_images << src_name
								else
									open(dest, 'wb'){|out|
										out.write(body)
									}
									success_images << src_name
								end
								
							end
						end
					end
					
				end
				
				unless (success_images + existed_images).empty? then
					opts[:message] = (success_images.map{|x| "画像 #{Util.escape_html(x)} のアップロードに成功しました。"} + 
					                  existed_images.map{|x| "画像 #{Util.escape_html(x)} は、同名の添付画像がすでに存在するためアップロードされませんでした。先に添付されている画像を削除してください。"}).join('<br>')
				end






				# プレビュー表示処理
				params = {}
				params[:title] = req.get_param('title').to_s
				params[:content] = req.get_param('content').to_s.gsub(/\r\n/, "\n")
				params[:invisible] = req.get_param('invisible')

				params[:tags] = req.tags
				params[:add_tag] = req.get_param('add_tag')
				params[:format] = req.get_param('format')
				params[:image_display] = req.get_param('image_display') || ID::DEFAULT
				
				opts[:tag_list] = @repository.get_tag_list([], true)
				opts[:parameters] = params
				opts[:attached_images] = (entry_id ? load_attached_images(entry_id) : load_temporary_attached_images)

				if entry_id then
					opts[:entry] = @repository.load_entry(req.params['id'])
					screen = EntryEditScreen.new(context, opts)
				else
					screen = EntryAddScreen.new(context, opts)
				end
				
				return screen
			elsif req.get_param('submit_complete') && context.master_mode? then
				return redirect(context, opts, (entry_id ? "entries/#{entry_id}" : ""), '動作サンプルでは記事の編集はできません。') if context.config.demo?
				# 入力チェック
				if not Util.static_entry_id?(entry_id) and req.get_param_str('title').empty? then
					return error(context, opts, "記事タイトルは省略できません。")
				end
				
				edited_id = nil
				to_path = nil
				# 書き込み
				@repository.lock{
					ids = @repository.get_entry_ids
					content = req.get_param_str('content')
					visible = !(req.get_param('invisible'))
					format = req.get_param('format')
					title = req.get_param_str('title')
					attached_image_display = req.get_param('image_display')
					
				
					if entry_id && Util.static_entry_id?(entry_id) then
						# スタティックエントリ
						opts = {:attached_image_display => attached_image_display}
						if ids.include?(entry_id) then
							@repository.edit_static_entry(entry_id, visible, title, content, format, opts)
						else
							@repository.add_new_static_entry(entry_id, visible, title, content, format, opts)
						end
						
						case entry_id
						when 'welcome'
							to_path = '/'
						when 'about_blog', 'about_writer'
							to_path = '/about'
						end
					else
						# 通常記事
						tags = req.tags + req.get_param_str('add_tag').split(/\s|　/)
						tags.uniq!
						
						opts = {:tags => tags, :attached_image_display => attached_image_display}
						if entry_id then
							@repository.edit_basic_entry(entry_id, visible, title, content, format, opts)
						else
							edited_id = Entry.create_new_id
							@repository.add_new_basic_entry(edited_id, visible, title, content, format, opts)
							
							# 一時アップロード画像のリネーム
							images = load_temporary_attached_images
							images.each do |img|
								src = @config.attached_dir_path + "__temp_#{img.name}"
								dest = @config.attached_dir_path + "#{edited_id}_#{img.name}"
								FileUtils.cp(src.cleanpath.to_s, dest.cleanpath.to_s)
							end

						end
						generate_news_feeds(context)
						
						# プレビューバックアップ削除
						path = @repository.preview_backup_file_path
						path.delete if path.exist?
						
						
						to_path = "entries/#{edited_id || entry_id}"
					end
					
				}
				
				

				return redirect(context, opts, to_path, "エントリの編集を完了しました。")
			end

		end
		
		def post_act_image(context, opts)
			req = context.request
			entry_id = req.get_param('entry_id')
			image_name = req.get_param('image_name')
			if entry_id then
				Util.validate_entry_id(entry_id)
			end
			return redirect(context, opts, "/entries/#{entry_id}/attached/#{image_name}", '動作サンプルでは、画像ファイルの操作はできません。') if context.config.demo?

			if context.master_mode? then
				
				Util.validate_entry_id(entry_id) or return error(context, opts, "エントリIDが不正です。")
				entry_id.untaint
				Util.validate(image_name, 1000) or	return error(context, opts, "画像名が長すぎます。")
				image_name.untaint

				
				src = @config.attached_dir_path + "#{entry_id}_#{image_name}"
			
				if req.get_param('submit_rename') then
					new_image_name = Util.encode_file_name(req.get_param('basename')) + File.extname(image_name)
					new_image_name.untaint
					dest = @config.attached_dir_path + "#{entry_id}_#{new_image_name}"
					
					if src.cleanpath == dest.cleanpath then
						return redirect(context, opts, "/entries/#{entry_id}/attached/#{image_name}", "変更前と変更後の名前が同じです。")
					elsif dest.exist? then
						return redirect(context, opts, "/entries/#{entry_id}/attached/#{image_name}", "#{new_image_name} という名前の画像ファイルがすでに存在しているため、変更できませんでした。")
					else
						@repository.lock{
							FileUtils.mv(src.untaint, dest)
						}
						return redirect(context, opts, "/entries/#{entry_id}/attached/#{new_image_name}", "名前を #{new_image_name} に変更しました。")
					end
				elsif req.get_param('submit_delete') then
					@repository.lock{
						src.delete
					}
					uri = (entry_id == '__temp' ? '/' : "/entries/#{entry_id}")
					return redirect(context, opts, uri, "添付画像 #{image_name} を削除しました。")
				else
					return error(context, opts, "不正な操作です。")
				end
			end
			
		end
		
		def post_menu(context, opts)
			text = ""
			DEFAULT_MENU_KEYS.each do |key|
				if key.in?(REQUIRED_MENU_KEYS) or context.request.get_param("#{key}_visible") then
					caption = context.request.get_param("#{key}_caption")
					text << "#{caption} | #{DEFAULT_MENU_COMMAND_TABLE[key]}" << "\n"
				end
			end

			@repository.lock{
				Util.write_text(@repository.dir_path + 'menu.txt', text)
				@repository.save_blog_config(@repository.load_blog_config.merge('menu_type' => MT::SIMPLE))
				self.load_config(@repository.blog_config_file_path) # reload for WEBrick
				@config.load_menu # reload for WEBrick
			}
			
			return redirect(context, opts, '/master_menu/menu_edit_form', 'メニューの編集を完了しました。')
		end
		
		def post_menu_text(context, opts)
			menu_text = context.request['menu_text']
			begin
				menu = Menu.parse(menu_text)
			rescue MenuError
				opts[:message] = $!.message
				opts[:menu_text] = menu_text
				return DirectMenuEditScreen.new(context, opts)
			rescue MenuItem::ArgumentParseError
				opts[:message] = "#{$!.text_line_number}行目（#{$!.menu_caption}）の引数が不正です。"
				opts[:menu_text] = menu_text
				return DirectMenuEditScreen.new(context, opts)
			end
			
			@repository.lock{
				Util.write_text(@repository.dir_path + 'menu.txt', menu_text)
				edit_blog_config do |data|
					data['menu_type'] = MT::DIRECT
				end
				@config.load_menu # reload for WEBrick
			}
			
			return redirect(context, opts, '/master_menu/menu_edit_form/direct', 'メニューの編集を完了しました。')
		end
		
		def post_html_customize(context, opts)
			if context.master_mode? then
				if context.config.demo? then
					return redirect(context, opts, "master_menu/html_customize", '動作サンプルでは、設定の変更はできません。') 
				end
				@repository.lock{
					dir_path = @repository.custom_html_dir_path
					Dir.mkdir(dir_path) unless dir_path.exist?

					Util.write_text(dir_path + 'head.html', context.request.get_param_str('head'))
					Util.write_text(dir_path + 'kizi_foot.html', context.request.get_param_str('kizi_foot'))
					Util.write_text(dir_path + 'body_foot.html', context.request.get_param_str('body_foot'))
					
					edit_blog_config do |data|
						data['extra_addresses'] = []
						(0...EXTRA_ADDRESS_NUMBER).each do |i|
							if (caption = context.request.get_param("extra_address_caption#{i}")) then
								data['extra_addresses'] << {'caption' => caption, 'href' => context.request.get_param_str("extra_address_href#{i}")}
							end
						end
					end
				}
				return redirect(context, opts, 'master_menu/html_customize', "変更を保存・適用しました。出力されるHTML文書を確認してください。")
			else
				return forbidden_proc.call
			end
		end
		
		def post_change_timestamp(context, opts)
			times = {}
		
			context.request.params.each_pair do |key, value|
				if key =~ /(last_modified|created)_(.+)/
					type, entry_id = $1, $2
					case type
					when 'last_modified'
						type_label = '更新日時'
					when 'created'
						type_label = '作成日時'
					else
						raise ArgumentError, "#{type} は未知の日付タイプです。"
					end
					
					if value.tr('０１２３４５６７８９', '0123456789') =~ /(\d+)\-(\d+)\-(\d+)\s+(\d+)\:(\d+)/ then
						year, mon, day, hour, min = $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i
						begin
							maked = Time.mktime(year, mon, day, hour, min)
						rescue ArgumentError
							return error(context, opts, "記事「#{@repository.load_entry(entry_id).title}」の#{type_label}（#{value}）を正しく読み取ることができませんでした（#{$!.message}）。表記中に余分な文字が入っているか、現在のシステム上で扱える日時の範囲を超えている可能性があります（多くのシステムでは1970年～2037年）。")
						end
						
						times[entry_id] ||= {}
						times[entry_id][type] = maked
					elsif value.empty? then
						return error(context, opts, "記事「#{@repository.load_entry(entry_id).title}」の#{type_label}が空欄です。")
					else
						return error(context, opts, "記事「#{@repository.load_entry(entry_id).title}」の#{type_label}（#{value}）を正しく読み取ることができませんでした。表記中に余分な文字が入っているか、一部の時間要素（時・分など）が欠けている可能性があります。")
					end
				end
			end
			
			@repository.lock{
				times.each_pair do |entry_id, data|
					entry = @repository.load_entry(entry_id)
					entry.last_modified = data['last_modified']
					entry.created = data['created']
					@repository.save_entry(entry)
				end
			}
			
			return redirect(context, opts, '/master_menu/entry_manager', '日時の変更を完了しました。')

		end
		
		def post_export(context, opts)
			entries = nil
			file_name = nil
			sec = Benchmark.realtime{
				# ファイル名確定
				file_name = context.request.get_param('file_name')
				unless file_name then
					return error(context, opts, '出力ファイル名が指定されていません。')
				end
				
				file_name = Util.encode_file_name(file_name)
				file_name.untaint	
				
				

				
				@repository.lock{
					temp_dir_path = @config.res_dir_path + 'temp/'
					FileUtils.mkdir(temp_dir_path) unless temp_dir_path.exist?
					dest = temp_dir_path + file_name
					
					entries = @repository.load_all_entries
					
					case context.request.get_param('format')
					when 'pblog'
						access_data = @repository.load_access_data
						image_table = load_attached_image_table(@repository.get_entry_ids)
						case context.request.get_param('compressing')
						when 'no'
							open(dest, 'w'){|out|
								Log::Pblog.export_to_io(out, entries, @config, access_data, image_table)
							}
						when 'gzip'
							require 'zlib'
							file_name += '.gz'
							Zlib::GzipWriter.open(dest.to_s + '.gz'){|gz|
								Log::Pblog.export_to_io(gz, entries, @config, access_data, image_table)
							}
						else
							return error(context, opts, '圧縮形式が指定されていません。')
						end
						
						
					when 'mt-compatible'
						log = Log::MTCompatible.export(entries, @module_handler)
						
						case context.request.get_param('encoding')
						when 'shift-jis'
							log = Uconv.u8tosjis(log)
						when 'euc-jp'
							log = Uconv.u8toeuc(log)
						when 'utf-8'
							# 何もしない
						else
							return error(context, opts, '文字コードが指定されていません。')
						end
						
						File.write(dest, log, 'wb')

					else
						return error(context, opts, '出力形式が指定されていません。')

					end
				
				}
			}
			
			return redirect(context, opts, '/master_menu/export/result', nil, "time=#{sec}&entry_number=#{entries.size}&file_name=#{Util.encode_url(file_name)}")
		end

		def post_import_file(context, opts)
			file_data = context.request.params['target']
			if file_data and not file_data[:filename].empty? then
				body = file_data[:tempfile].read
				format = context.request.get_param('format')
				
				# ファイル形式判別＆エンコーディング変換
				if format == 'auto' then
					format = Log.guess_format(file_data[:filename], body)
				
					unless format then
						return error(context, opts, 'ファイル形式の自動判別に失敗しました。明示的にファイル形式を指定してください。')
					end
				end
				
				# 文字コードの変換
				case format
				when LF::MT_COMPATIBLE_UTF8, LF::PBLOG, LF::PBLOG_GZIP
					# no action
				when LF::MT_COMPATIBLE_SJIS
					body = Uconv.sjistou8(body)
				when LF::MT_COMPATIBLE_EUC
					body = Uconv.euctou8(body)
				else
					return error(context, opts, "未知のファイル形式（#{format}）が指定されています。")
				end
				
				entry_ids = nil
				entries = nil
				access_data = nil
				image_data = nil
				@repository.lock{
					# 記事IDリスト読み込み
					entry_ids = @repository.get_entry_ids
					Util.touch_dir(@config.res_dir_path + 'temp/')
					File.write(@config.res_dir_path + 'temp/imported', body, 'wb')
				
					# インポート処理
					case format
					when LF::MT_COMPATIBLE_UTF8, LF::MT_COMPATIBLE_EUC, LF::MT_COMPATIBLE_SJIS
						body.gsub!(/\r\n/, "\n")
						mt_entries = Log::MTCompatible.import(body)
						entries = mt_entries.map{|x| Log::MTCompatible.entry_to_pb_entry(x)}
					when LF::PBLOG
						entries, access_data, image_data = Log::Pblog.import(body)
					when LF::PBLOG_GZIP
						begin
							require 'zlib'
						rescue Exception
							return error(context, opts, 'この環境にはzlibがインストールされていないため、Gzip形式で圧縮されたファイルは読み込めません。')
						end
						
						Zlib::GzipReader.wrap(StringIO.new(body)){|gz|
							body = gz.read
						}
						entries, access_data, image_data = Log::Pblog.import(body)
						
					end
				
					# 一時ファイル描き込み
					Util.write_text(@config.res_dir_path + 'temp/imported', body)
				}

				
				if defined?(image_data) then
					opts[:image_sizes] = []
					opts[:image_numbers] = []
					image_data.each do |data|
						if data.empty? then
							opts[:image_sizes] << 0
							opts[:image_numbers] << 0
						else
							opts[:image_sizes] << data.map{|x| x['Body'].length * 3 / 4}.total
							opts[:image_numbers] << data.size
						end
					end
				end

				
				opts[:format] = format
				
				# 新規追加記事と上書き記事により分ける
				opts[:new_entry_data] = []
				opts[:overlap_entry_data] = []
				
				entries.each_with_index do |entry, i|
					if entry.id and entry.id.in?(entry_ids) then
						opts[:overlap_entry_data] << [i, entry]
					else
						opts[:new_entry_data] << [i, entry]
					end
				end
				
				return ImportEntrySelectScreen.new(context, opts)
			else
				error(context, opts, 'インポートしたいファイルを指定してください。')
			end
		end
		
		def post_import_list(context, opts)
			if context.master_mode? then
		
				indexies = context.request.get_param_array('indexies')
				
				if indexies.empty? then
					return error(context, opts, 'インポート対象の記事が存在しません。')
				end
				
				sec = Benchmark.realtime{
					@repository.lock{
						# インポート処理
						
						path = @config.res_dir_path + 'temp/imported'
						body = Util.read_text(path)
						case (format = context.request.get_param('format'))
						when LF::PBLOG, LF::PBLOG_GZIP
							imported_entries, imported_access_data, image_data = Log::Pblog.import(body)
							access_data = @repository.load_access_data
							
							indexies.each do |index|
								target = imported_entries[index.to_i]
								target.id ||= Entry.create_new_id(target.created)
								@repository.save_entry(target)
								
								access_data['counts'][target.id] = imported_access_data['counts'][target.id]
								access_data['referers'][target.id] = imported_access_data['referers'][target.id]
								
								image_data[index.to_i].each do |data|
									image_path = @config.attached_dir_path + "#{target.id}_#{data['Name']}"
									open(image_path, 'wb'){|f|
										f.write(data['Body'].unpack('m*')[0])
									}
								end
							end
							
							Util.write_text(@repository.access_data_file_path, AnJSON.pretty_build(access_data))
							
						else
							
							mt_entries = Log::MTCompatible.import(body)
							imported_entries = mt_entries.map{|x| Log::MTCompatible.entry_to_pb_entry(x)}
							current_entries = @repository.load_all_entries
							
							indexies.each do |index|
								target = imported_entries[index.to_i]
								target.id ||= Entry.create_new_id(target.created)
								@repository.save_entry(target)
							end
						end
						File.unlink(path)
					}
				}
				
				return redirect(context, opts, '/master_menu', "#{indexies.size}記事のインポート処理を完了しました。記事を正しく取り込めているかどうか確認してください。")
			else
				return ForbiddenScreen.new(context, opts)
			end
		end
		
		def post_snapshot(context, opts)
			return redirect(context, opts, '/master_menu', '動作サンプルではスナップショット機能は使えません。') if context.config.demo?
			sec = Benchmark.realtime{
				generate_snapshot(context.request)
			}
			
			return redirect(context, opts, '/master_menu/snapshot/result', nil, "time=#{sec}")

		end

=begin
		def request_app(context, opts)
			
			case context.request.path_items[1]
			when 'entries'
				if context.request.path_items[2] then
					return AtomEntry.new(context, @repository.load_entry(context.request.path_items[2]))
				else
					return AtomEntryCollection.new(context, @repository.load_all_entries)
				end
			else
				return AtomService.new(context)
			end
		end
=end
		
	end
	
	class ApplicationStub < Application
		def initialize(config = Config.new)
			super
			@config = config
			@repository = RepositoryStub.new(@config.data_dir_path)
			@module_handler = ModuleHandler.new(@config)
			@master_session_ids = []
		end
		
		def load_session_id
			return nil
		end

	end
end
