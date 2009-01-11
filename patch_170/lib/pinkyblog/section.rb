#-> Section
require 'tenjin'
require 'amrita/template'

require 'pinkyblog/const'
require 'pinkyblog/util'
require 'pinkyblog/config'
require 'pinkyblog/module-handler'
require 'pinkyblog/request'
require 'pinkyblog/image'
require 'pinkyblog/option-check'


module PinkyBlog
	# HTML上での一つ一つのセクションを表すクラス（通常、Screenから使う）
	class Section
		include Amrita::ExpandByMember
		self.extend OptionCheck

		def initialize(context, option_args = {})
			@context = context
			
			self.class.assert_fulfill_requirement(option_args)
			self.class.set_defaults(option_args)
			
			option_args.each_pair do |key, value|
				instance_variable_set("@#{key}", value)
			end
			
			@options = option_args
			
		end
		
		def amrita_default_model
			{:post_path => post_path}
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

		
		
		def body
			"content."
		end
		
		def header
			header_text
		end
		
		def header_text
			"section title"
		end
		
		def footer
			nil
		end
		
		def header_text_id
			nil
		end
		
		def modori
			{:href => '#PAGETOP'}
		end
		

		def post_path
			@context.route_to('/post')
		end
		
		def get_image_div(entry_id, images, image_display = ID::DEFAULT)
			entry_id ||= '__temp'
			re = ""
			if not images.empty? and image_display != ID::INVISIBLE then
			
				case image_display
				when ID::SMALL_SIZE, ID::ORIGINAL_SIZE
					re << %Q|<div class="pinky-thumbnails">\n|
				when ID::LINK
					re << '<ul class="pinky-attached-image-list">'
				end
				
				images.each do |img|
					src = @context.file_route_to(config.attached_dir_path + "#{entry_id}_#{img.name}")
					href = @context.route_to("/entries/#{entry_id}/attached/#{img.name}")
					
					case image_display
					when ID::SMALL_SIZE, ID::ORIGINAL_SIZE
						w, h = img.width, img.height
						
						if image_display == ID::SMALL_SIZE then
							# 縮小
							max = 200
							if w > max or h > max then
								if w > h then
									rate = max / w.to_f
									w = max
									h = (h.to_f * rate).to_i
								else
									rate = max / h.to_f
									h = max
									w = (w.to_f * rate).to_i
								end
							end
						end
						
						re << %Q|\t<a href="#{href}"><img src="#{src}" width="#{w}" height="#{h}" border="0"></a>\n|

					when ID::LINK
						re << %Q|\t<li><a href="#{href}">#{img.name}</a> (#{img.info})</li>\n|
					end					
					
					
				end
				
				case image_display
				when ID::SMALL_SIZE, ID::ORIGINAL_SIZE
					re << '</div>'
				when ID::LINK
					re << '</ul>'
				end
			end
			
			re
		end
		
		def get_small_tag_list(tags)
			if tags.empty? then
				return ''
			else
				html = 'タグ:'
				tags.each do |tag|
					href = @context.route_to('/entries', "tags=#{Util.encode_base64url(tag)}")
					html << %Q|<a href="#{href}" title="このタグを含む記事を一覧表示">#{Util.escape_html(tag)}</a> |
				end
				
				return Amrita::SanitizedString.new(html)
			end
		end
		
		
		
		def expand_amrita_template(tmpl_path, model = {})
			path = config.lib_dir_path + 'pinkyblog/template/' + tmpl_path
			tmpl = Amrita::TemplateText.new(path.read.untaint)
			tmpl.amrita_id = 'amrita_src'
			buf = Amrita::SanitizedString.new
			tmpl.expand(buf, model)
			return buf
		end
		
		
		def expand_tenjin_template(tmpl_name, context)
			path = config.lib_dir_path + 'pinkyblog/template/' + tmpl_name
			tenjin = Tenjin::Engine.new
			context[:view_context] = @context
			context[:vc] = @context
			return Amrita::SanitizedString.new(tenjin.render(path.to_s, context))
			
		end

		
	
	end
	
	class DebugInformationSection < Section
		def header_text
			'デバッグ情報'
		end
		
		def body
			re = ''
			re << "[CGI環境変数]\n"
			
			list = %w(REQUEST_METHOD PATH_INFO SCRIPT_NAME SERVER_SOFTWARE QUERY_STRING).sort
			list.each do |key|
				re << sprintf("  %-16s : %s\n", key, ENV[key])
			end
			
			re << "[script URI]\n" << "  #{request.script_uri}\n"
			
			
			return Amrita::SanitizedString.new("<pre>#{Util.escape_html(re)}</pre>")
		end
	end


	class NavigationSection < Section
	
		require_opt :prev_href, :prev_caption, :next_href, :next_caption
	
		def header_text
			nil
		end
		
		def body
			model = amrita_default_model
			
			case config.page_changing_type
			when PCT::SEQUENTIAL
				if @prev_href && @prev_caption then
					model[:prev_a] = {}
					model[:prev_a][:href] = @prev_href
					model[:prev_a][:caption] = @prev_caption
				end
				if @next_href && @next_caption then
					model[:next_a] = {}
					model[:next_a][:href] = @next_href
					model[:next_a][:caption] = @next_caption
				end
			when PCT::INDEX
				page_number = [(@total - 1) / @page_length + 1, 1].max
				current = [@start / @page_length + 1, 1].max
				buf = []
				(1..page_number).each do |i|
					if i == current then
						buf << %Q|<em>page #{i}</em>|
					else
						if @context.snapshot_mode? then
							href = Util.page_number_to_file_name('entries', i)
						else
							href = "?start=#{(i - 1) * @page_length}"
						end
						
						if @extend_query and not @context.snapshot_mode? then
							href << '&' << @extend_query
						end
						buf << %Q|<a href="#{href}">page #{i}</a>|
					end
				end
				
				model[:index] = Amrita::SanitizedString.new(buf.join(' - '))
			end
			


			return expand_amrita_template("navigation.html", model)
			
			
		end
		
		def footer
			return nil
		end
		
		def modori
			return nil
		end
	end

	
	class HeadlineSection < Section
		require_opt :entries


		def header_text
			config.headline_title
		end
		
		
		def body
			model = amrita_default_model
			model[:items] = []
			
			counts = nil
			@entries.sort!{|a,b| b.last_modified <=> a.last_modified}.each do |entry|
				model[:items] << {
					:a => {
						:name => entry.title_caption,
						:href => @context.route_to("entries/#{entry.id}")
					}
				}
				
				if entry.edited_number == 0 then
					model[:items].last[:info] = Amrita::SanitizedString.new(" - " + @context.date2str(entry.created) + "作成")
				else
					model[:items].last[:info] = Amrita::SanitizedString.new(" - " + @context.date2str(entry.last_modified) + "更新")
				end
				
				html = get_small_tag_list(entry.normal_tags)
				if not @context.snapshot_mode? and not html.empty? then
					model[:items].last[:info] << " - " << html
				end
				
			end

			
			
			return expand_amrita_template('headline.html', model)
			
			
		end
		
	end
	
	class MessageFormSection < Section
		default_opt :default_name, ""
		default_opt :default_address, ""


		def header_text
			config.message_form_title
		end
		
		def body
			model = amrita_default_model
			model[:guide] = config.message_form_guide
			
			return expand_amrita_template("message_form.html", model)
			
		end
	end


	class MessageSection < Section
		require_opt :message
		
		def header_text
			nil
		end
		
		def body
			return Amrita::SanitizedString.new("<p><em>#{@message}</em></p>")
		end
		
		def modori
			nil
		end
	end

	

	
	class WarningSection < Section
		require_opt :warnings
		
		def header_text
			nil
		end
		
		def modori
			nil
		end
		
		def body
			model = amrita_default_model
			model[:items] = []
			@warnings.each do |warning|
				model[:items] = {:message => warning.to_s}
			end
			
			return expand_amrita_template("warning.html", model)

		end
	end
	
	class ErrorSection < Section
		require_opt :body, :http_status
		
		def header_text
			"エラー : #{@http_status}"
		end
		
		def body
			return Amrita::SanitizedString.new("<p>#{@body}</p>")
		end
	end
	
	class PostBlockSection < Section
		def header_text
			"エラー : #{HTTP_BAD_REQUEST}"
		end
		
		def body
			return expand_amrita_template("post_block.html", {})
		end
	end
	
	class AttachedImageSection < Section
		require_opt :entry, :image
		
		def header_text
			@image.name
		end
		
		def body
			model = amrita_default_model
			path = config.attached_dir_path + "#{@entry.id}_#{@image.name}"
			#path.untaint
			model[:src] = @context.file_route_to(path)
			model[:width] = @image.width
			model[:height] = @image.height
			model[:filesize] = Util.size_to_kb(@image.file_size)
			
			if @context.master_mode? then
				model[:action_form] = {}
				model[:action_form][:basename] = File.basename(@image.name, '.*')
				model[:action_form][:extname] = File.extname(@image.name)
				model[:action_form][:post_uri] = @context.route_to('/post')
				model[:action_form][:entry_id] = @entry.id
				model[:action_form][:image_name] = @image.name
			end
		
			return expand_amrita_template("attached_image.html", model)
		end

		
	end

	
	class EntrySection < Section
		require_opt :entry
		require_opt :module_handler
		default_opt :ex_footer_visible, true
		default_opt :attached_images, []
		
		def header_text
			@entry.title_caption
		end
		

		def body
			html = ''
			html << get_image_div(@entry.id, @attached_images, @entry.attached_image_display)
			html << @module_handler.translate(@entry.format, @entry.content || '')
			
			return(Amrita::SanitizedString.new(html))
		end
		
		def footer
			model = amrita_default_model
			model[:items] = []
			
			
			if master_mode? then
				model[:items] << {:href => @context.route_to("/entries/#{@entry.id}/edit_form"), :caption => "この記事を編集"}
			end
			
			model[:items] << Amrita::SanitizedString.new(get_small_tag_list(@entry.normal_tags))
			
			if @ex_footer_visible and not @entry.kind_of?(StaticEntry) then
				case config.auto_date_display_type
				when ADDT::CREATED
					model[:items] << "作成:#{@context.date2str(@entry.created)}"
				when ADDT::UPDATED
					model[:items] << "更新:#{@context.date2str(@entry.updated)}"
				end

				unless @entry.find_special_tag(:url_invisible) then
					model[:items] << {:href => @context.route_to("/entries/#{@entry.id}"), :caption => "この記事のURL"}
				end
				if config.use_comment? and @entry.commentable? then
					model[:items] << {:href => @context.route_to("/entries/#{@entry.id}", nil, 'COMMENT'),
					                  :caption => "コメント:#{@entry.existing_comments.size}"} 
				end
				
			end
			
				
			return model
		end
	end
	
	class EntryListSection < Section
		require_opt :entries, :access_counts


		def header_text
			'記事の一覧'
		end
		
		def body
			data = Tenjin::Context.new
			data[:items] = []

			@entries.each do |entry|
				data[:items] << {
					:caption => entry.title_caption,
					:href => @context.route_to("/entries/#{entry.id}")
				}
				case request.sort
				when Sort::BY_CREATED, Sort::BY_TITLE
					data[:items].last[:info] = @context.date2str(entry.created) + "作成"
				when Sort::BY_ACCESS
					data[:items].last[:info] = (@access_counts[entry.id.to_s] || 0).to_s + " アクセス"
				when Sort::BY_MODIFIED
					data[:items].last[:info] = @context.date2str(entry.last_modified) + "更新"
				when Sort::BY_FILE_SIZE
					data[:items].last[:info] = Util.size_to_b(entry.content.length)
				end
			end
			
				
			data[:action_path] = @context.route_to("/entries")
			if request.tags.empty? then
				data[:filter_info] = ''
			else
				tag_info = request.tags.map{|x| "[#{x}]"}
				data[:filter_info] = "（タグ#{tag_info.join}がついた記事のみ表示）"
			end
			
			return expand_tenjin_template('entry_list.rbhtml', data)
		
			
			
		end
		
	end


	
	class PreviewSection < Section
		require_opt :module_handler, :content, :format, :image_display
		default_opt :attached_images, []
		
		def header_text
			'プレビュー'
		end
		
		def body
			re = ""
			
			re << get_image_div(request.get_param('id'), @attached_images, @image_display)
			re << @module_handler.translate(@format, @content)
			
			Amrita::SanitizedString.new(re)

		end

	end
	
	class EntryInformationSection < Section
		require_opt :entry, :referer_list
		
		def header_text
			return Amrita.a({:id => 'ENTRYINFO'}){"この記事の情報"}
		end

		def body
			model = amrita_default_model

			unless @entry.find_special_tag(:url_invisible) then
				model[:url_dt] = {}
				model[:url_dd] = @context.absolute_uri_to("/entries/#{@entry.id}")
			end
			model[:last_modified] = @context.time2str(@entry.last_modified)

			if master_mode? || config.referer_visible? then
				model[:referer_dt] = {}
				model[:referer_dd] = {:items => []}
				
				@referer_list.each do |url, site_name, count|
					unless site_name == '-'  then
						model[:referer_dd][:items] << {:href => url, :count => count.to_s, :caption => (site_name || Util.clip(url, REFERER_MAX_LENGTH))}
					end
				end
			end

			
			# タグはここには表示しないことになりました
			#if not @entry.is_a?(StaticEntry) and not snapshot_mode? then
			#	model[:tags_dt] = {}
			#	model[:tags_dd] = {}
			#	model[:tags_dd][:tags] = @entry.normal_tags.map do |tag|
			#		query = Util.tags_to_query([tag])
			#	{:href => @context.absolute_uri_to('/entries', query), :name => tag, :title => "タグ「#{tag}」を含む記事を一覧表示"}
			#	end
			#	
			#end
			return expand_amrita_template("entry_information.html", model)
		end
		
	end
	
	
	class TagListSection < Section
		require_opt :tag_list
		
		def header_text
			return (request.tags.empty? ? "タグで絞り込む" : "タグでさらに絞り込む")
		end

		def body
			model = amrita_default_model
			
			model[:tags] = []
			@tag_list.each do |tag, count|
				query = Util.tags_to_query(request.tags + [tag])
				query << "&sort=#{request.sort}"
				if request.get_param('order') then
					query << '&order=' << request.get_param('order')
				end
				model[:tags] << {:href => @context.route_to('/entries', query), :name => "#{tag}(#{count})"}
			end

			model[:tags] << {:name => "タグ絞り込みを解除" , :href => @context.route_to('/entries')} unless request.tags.empty?
			
			
			return expand_amrita_template("tag_list.html", model)
		end
		
		def modori
			nil
		end
		
	end

	
	
	class EntryEditFormSection < Section
		require_opt :entry, :tag_list, :parameters, :module_handler
		default_opt :attached_images, []

		def header_text
			(@entry ? "記事「#{@entry.title}」の編集" : "新しい記事を書く")
		end
		
		def body
		
			model = amrita_default_model
			if @parameters then
				model[:title] = {:value => @parameters[:title]}
			elsif @entry then
				model[:title] = {:value => @entry.title}

			else
				model[:title] = {:value => ''}
			end
			
			if @parameters then
				model[:content] = Amrita::SanitizedString.new(Util.escape_html(@parameters[:content]))
			elsif @entry then
				model[:content] = Amrita::SanitizedString.new(Util.escape_html(@entry.content || ''))
			else
				model[:content] = ""
			end
			
			model[:format] = {}
			model[:format][:items] = []
			mod_list = @module_handler.translator_modules.to_a
			mod_list.sort!{|x, y| x[0] <=> y[0]} # 名前順
			selected = (@parameters && @parameters[:format]) || (@entry && @entry.format) || config.default_translator
			mod_list.each do |name, mod|
				model[:format][:items] << {:value => name, :caption => mod::CAPTION}
				model[:format][:items].last[:selected] = 'true' if name == selected
			end
			
			model[:format_guide] = @context.route_to('format_guide')
			
			unless @entry && @entry.is_a?(StaticEntry) then
				model[:tag] = {}
				model[:tag][:list] = []
				i = 0
				@tag_list.each do |name, count|
					model[:tag][:list] << {:name => "tags_#{i}", :value => Util.encode_base64url(name), :caption => name + "(#{count})"}
					if @parameters then
						model[:tag][:list].last[:checked] = @parameters[:tags].include?(name) && 'true'
					elsif @entry then
						model[:tag][:list].last[:checked] = @entry.tags.include?(name) && 'true'
					end
					i += 1
				end
				
				model[:tag][:add_tag] = @parameters && @parameters[:add_tag]

			end
			
			if @parameters then
				# プレビュー
				model[:invisible_checked] = 'checked' if @parameters[:invisible]
			elsif @entry then
				# 既存エントリの編集画面（開いた直後）
				model[:invisible_checked] = 'checked' if @entry.invisible?
			end
			
			if config.use_image_attaching? then
				model[:attach_form] = {}
				unless @attached_images.empty? then
					model[:attach_form][:image_display] = {}
					# 添付画像の表示形式選択
					if @parameters and @parameters[:image_display] then
						key = @parameters[:image_display].tr('-', '_').untaint
					elsif @entry then
						key = @entry.attached_image_display.tr('-', '_').untaint
					else
						key = 'small_size'
					end
				
					model[:attach_form][:image_display]["#{key}_selected".to_sym] = 'selected'
				
					# 画像リスト
					model[:attach_form][:image_list] = {:items => []}
					@attached_images.each do |img|
						model[:attach_form][:image_list][:items] <<  {:href => @context.route_to("/entries/#{(@entry ? @entry.id : '__temp')}/attached/#{img.name}"),
						                                              :width => img.width, :height => img.height, :name => img.name,
																							            :filesize => img.info}
					end
				end
			end
			

			

			model[:id] = {:value => @entry.id} if @entry
			
			
			return expand_amrita_template("entry_edit_form.html", model)
			
			
		end
	end
	
	class FormatGuideSection < Section
		require_opt :module_handler

		def header_text
			"記事の書き方について"
		end
		
		def body
			model = amrita_default_model
			model[:format_list] = {}
			model[:format_list][:items] = []
			mod_list = @module_handler.translator_modules.to_a
			mod_list.sort!{|x, y| x[0] <=> y[0]} # 名前順
			mod_list.each do |name, mod|
				model[:format_list][:items] << {:name => name, :href => @context.route_to("format_guide/#{name}"),
				                                :caption => mod::CAPTION}
			end
			
			
			return expand_amrita_template("format_guide.html", model)
			
			
		end
	end


	class FormatDetailSection < Section
		require_opt :module_handler

		def header_text
			"#{@module_handler.translator_modules[format_name]::CAPTION}"
		end
		def format_name
			request.path_info.split('/').last
		end
		def body
			translator = @module_handler.get_translator(format_name)
			return Amrita::SanitizedString.new(@module_handler.translate(format_name, translator.format_guide.gsub(/\r\n/, "\n")))
		end
	end
	

	class FormatDetailSourceSection < Section

		def header_text
			"元になったテキスト"
		end
		def format_name
			request.path_items[1]
		end
		def body
			
			translator = get_translator(format_name)
			return Amrita::SanitizedString.new("<pre>" + Util.escape_html(translator.format_guide) + "</pre>")
		end
	end


	class CommentSection < Section
		require_opt :comments, :entry

		def header_text
			Amrita.a({:id => 'COMMENT'}){"コメント"}
		end
		
		def body
			model = amrita_default_model
			model[:comments] = []
			@comments.each_index do |i|
				comment = @comments[i]
				next if comment.deleted?
				
				info = @context.time2str(comment.time)
				
				if comment.edited_number >= 1 then
					info << "　（#{comment.edited_number}回編集）"
				end
				
				if master_mode? and comment.mail_address then
					info << %Q|<br><a href="mailto:#{comment.mail_address}">#{comment.mail_address}</a>|
				end
				if master_mode? or comment.password_sha then
					path = "/entries/#{@entry.id}/comments/#{i+1}/edit_form"
					uri = @context.route_to(path)
					#sect_uri = @context.route_to(path, 'view=section')
					#info << %Q|<br><a href="#{uri}" onclick="return edit_comment(this, '#{sect_uri}', #{i});">このコメントを編集/削除</a>|
					info << %Q|<br><a href="#{uri}">このコメントを編集/削除</a>|
				end
				
				model[:comments] << {
					:id => "COMMENT-#{i}",
					:header => (comment.writer ? "#{i+1} : #{comment.writer}" : "#{i+1} :"),
					:content => Amrita::SanitizedString.new(comment.content_html),
					:info => Amrita::SanitizedString.new(info)
				}
			end

			
			return expand_amrita_template("comment.html", model)
			
			
		end
	end

	
	class CommentFormSection < Section
		require_opt :entry_id, :default_name, :default_address


		def header_text
			Amrita.a({:id => 'COMMENT-FORM'}){"この記事にコメントする"}
		end
		
		def body
			model = amrita_default_model
			model[:entry_id] = @entry_id
			model[:name] = @default_name
			model[:address] = @default_address
			model[:content] = {}
			if @context.master_mode? then
				model[:password_form] = '（管理者はすべてのコメントを編集/削除できるため、パスワード入力の必要がありません）'
			else
				model[:password_form] = {}
			end
			model[:submit_value] = 'コメントを送信'
			model[:action] = 'comment'
			
			model[:name_info] = (config.commentator_name_required? ? Amrita::SanitizedString.new('<em>必須</em>') : '空欄可')
			model[:address_info] = (config.commentator_address_required? ? Amrita::SanitizedString.new('<em>必須</em>') : '空欄可')
			
			return expand_amrita_template("comment_form.html", model)
			
		end
	end
	
	class CommentEditFormSection < Section
		require_opt :entry_id, :comment_index, :default_name, :default_address, :default_content


		def header_text
			"コメント#{@comment_index + 1}番の編集"
		end
		
		def body
			model = amrita_default_model
			model[:entry_id] = @entry_id
			model[:comment_index] = @comment_index
			model[:name] = @default_name
			model[:address] = @default_address
			model[:content] = @default_content
			if @context.master_mode? then
				model[:password_form] = '（管理者はすべてのコメントを編集/削除できるため、パスワード入力の必要がありません）'
			else
				model[:password_form] = {}
			end
			model[:submit_value] = '編集を完了して送信'
			model[:action] = 'edit_comment'
			
			model[:name_info] = (config.commentator_name_required? ? Amrita::SanitizedString.new('<em>必須</em>') : '空欄可')
			model[:address_info] = (config.commentator_address_required? ? Amrita::SanitizedString.new('<em>必須</em>') : '空欄可')
			
			return expand_amrita_template("comment_form.html", model)
			
		end
	end
	
	class CommentDeleteFormSection < Section
		require_opt :entry_id, :comment_index


		def header_text
			"コメント#{@comment_index + 1}番の削除"
		end
		
		def body
			model = amrita_default_model
			model[:entry_id] = @entry_id
			model[:comment_index] = @comment_index
			if @context.master_mode? then
				model[:password_form] = '（管理者はすべてのコメントを編集/削除できるため、パスワード入力の必要がありません）'
			else
				model[:password_form] = {}
			end
			
			return expand_amrita_template("comment_delete_form.html", model)
			
		end
	end



	
	
	class MasterMenuSection < Section
		def header_text
			"管理者メニュー"
		end
		
		def body
			model = amrita_default_model
			model[:entry_add_form] = @context.route_to('/master_menu/entry_add_form')
			model[:message_list] = @context.route_to('/master_menu/message_list')
			model[:entry_manager] = @context.route_to('/master_menu/entry_manager')
			model[:menu_edit_form] = @context.route_to('/master_menu/menu_edit_form')
			model[:blog_config] = @context.route_to('/master_menu/blog_config')
			model[:post_limit] = @context.route_to('/master_menu/post_limit')
			model[:mail_notification_config] = @context.route_to('/master_menu/mail_notification_config')
			model[:referer_config] = @context.route_to('/master_menu/referer_config')
			model[:snapshot] = @context.route_to('/master_menu/snapshot')
			model[:html_customize] = @context.route_to('/master_menu/html_customize')
			model[:logout] = @context.route_to('/', 'logout=1')
			model[:import] = @context.route_to('/master_menu/import')
			model[:export] = @context.route_to('/master_menu/export')
			if config.demo? then
				model[:demo_caution] = {}
			else
				model[:system_monitor] = @context.route_to('/master_menu/system_monitor')
				
			end
			return expand_amrita_template("master_menu.html", model)
			
			
		end
	end
	
	class SystemInformationSection < Section
	
		def header_text
			"システム情報"
		end
		
		def body
			model = amrita_default_model
			model[:core_version] = (config.demo? ? "#{CORE_VERSION}（サンプル動作中）" : CORE_VERSION)
			model[:ruby_version] = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
			model[:disp_env] = {:href => @context.route_to('/master_menu/env')} if @context.master_mode?
			return expand_amrita_template("system_information.html", model)
			
			
		end
	end
	
	class SystemMonitorSection < Section
	
		def header_text
			"システムモニター"
		end
		
		def body
			model = amrita_default_model

=begin
			model[:env] = []		
			request.env.keys.sort.each do |key|
				value = request.env[key]
				unless value.kind_of?(String) then
					value = value.inspect
				end
				
				model[:env] << key << value
			end
=end
			
			
			
			data = [
				[:data_dir_path, '記事データファイル、blogの設定ファイルなど'],
				[:res_dir_path, '記事への添付画像、標準添付の画像・CSSファイルなど'],
				[:cdp_dir_path, 'CSS着せ替えテンプレート'],
				[:lib_dir_path, 'Pinky:blogのシステム本体（ライブラリ）'],
				[:mod_dir_path, 'モジュール（機能拡張スクリプト）'],
			]
			model[:disk_use] = []
			data.each do |key, desc|
				path = config.send(key)
				pattern = path + '**/*'
				size = Pathname.glob(pattern).each{|x| x.untaint}.map{|x| (x.file? ? x.size : 0)}.total || 0
				
				model[:disk_use] << {
					:path => path, :size => Util.size_to_kb(size), :description => desc,
					:tree_href => @context.route_to("/master_menu/system_monitor/tree/#{key.to_s}")
				}
			end
			
			model[:perfomance] = []
			@time_data.each do |caption, time|
				model[:perfomance] << caption << sprintf('%.3f 秒', time)
			end
			
			model[:pwd] = Dir.pwd
			
			data = [
				['バージョン', "Pinky:blog #{CORE_VERSION}"],
				['rubyのバージョン', "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"],
				[],
				['@data_dir_path', config.data_dir_path],
				['@res_dir_path', config.res_dir_path],
				['@cdp_dir_path', config.cdp_dir_path],
				['@lib_dir_path', config.lib_dir_path],
				['@mod_dir_path', config.mod_dir_path],
				[],
				['request.url', request.url],
				['request.path_info', request.path_info],
				[],
			]
			
			keys = %w(PATH_INFO PATH_TRANSLATED QUERY_STRING REMOTE_ADDR REMOTE_HOST HTTP_USER_AGENT
			          SCRIPT_NAME SERVER_NAME SERVER_PORT SERVER_PROTOCOL SERVER_SOFTWARE HTTP_HOST)
			keys.sort.each do |key|
				data << [key, request.env[key] || '(null)']
			end
			
			model[:debug_info] = ""
			data.each do |label, value|
				if label then
					model[:debug_info] << sprintf("%s : %s", label, value) << "\n"
				else
					model[:debug_info] << "\n"
				end
			end
		
			model[:parity_check_href] = @context.route_to('/master_menu/system_monitor/parity_check')
			
			return expand_amrita_template("system_monitor.html", model)
		end
	end
	
	class FileTreeSection < Section
		require_opt :root
		
		def header_text
			"ファイルツリー（#{@root}）"
		end
		
		def body
			buf = "<pre>" + Util.escape_html(Util.format_file_tree(@root)) + "</pre>"
			buf << %Q|<ul><li><a href="#{@context.route_to('/master_menu/system_monitor')}">システムモニターへ戻る</a></li></ul>|
		
			Amrita::SanitizedString.new(buf)
		end
	end
	
	class ParityCheckSection < Section
		def header_text
			"記事データファイル状態チェック"
		end
		
		def body
			rows = @result_data
			
			expand_amrita_template('parity_check.html', {:rows => rows, :back_href => @context.route_to('/master_menu/system_monitor')})
		end
	end


	

	class NotifyingSection < Section
		require_opt :notifications

		def header_text
			nil
		end
		
		def body
			model = amrita_default_model
			model[:items] = []
			model[:items] = @notifications.map{|x| {:caption => x} }
			return expand_amrita_template("notifying.html", model)
			
			
		end
		
		def modori
			nil
		end
	end
	
	class MessageListSection < Section
		require_opt :messages
		
		def header_text
			"ひとことメッセージ一覧"
		end
		
		def body
			model = amrita_default_model
			model[:items] = []
			@messages.sort!{|a, b| b.time <=> a.time}
			@messages.each do |msg|
				model[:items] << {:id => msg.uuid, :content => msg.content, :time => @context.time2str(msg.time)}
			end
			return expand_amrita_template("message_list.html", model)
		end
	end
	


	
	class BlogConfigFormSection < Section
		require_opt :module_handler


		def header_text
			"blog設定"
		end
		
		def body
			model = amrita_default_model
			model[:site_title] = config.site_title
			model[:writer_name] = config.writer_name
			model[:writer_address] = config.writer_address || ''
			model[:home_url] = config.home_url || ''
			model[:about_visible] = config.about_visible
			model[:headline_title] = config.headline_title
			model[:message_form_visible] = config.message_form_visible
			model[:message_form_title] = config.message_form_title
			model[:message_form_guide] = config.message_form_guide
			
			model[:use_comment] = (config.use_comment? && 'checked')
			model[:commentator_name_required] = (config.commentator_name_required? && 'checked')
			model[:commentator_address_required] = (config.commentator_address_required? && 'checked')
			model[:use_image_attaching] = (config.use_image_attaching? && 'checked')
			
			model[:page_changing_type_sequential] = (config.page_changing_type == PCT::SEQUENTIAL && 'checked')
			model[:page_changing_type_index] = (config.page_changing_type == PCT::INDEX && 'checked')

			model[:auto_date_display_type_no] = (config.auto_date_display_type == ADDT::NO && 'checked')
			model[:auto_date_display_type_created] = (config.auto_date_display_type == ADDT::CREATED && 'checked')
			model[:auto_date_display_type_updated] = (config.auto_date_display_type == ADDT::UPDATED && 'checked')
			
			model[:default_translator] = []
			@module_handler.translator_modules.to_a.sort.each do |name, mod|
				m = {}
				m[:caption] = mod::CAPTION
				m[:value] = name
				m[:selected] = 'true' if name == config.default_translator
				model[:default_translator] << m
			end
			
			
			return expand_amrita_template("blog_config_form.html", model)
			
		end
	end
	
	class MenuEditFormSection < Section
		require_opt :menu_text

		def header_text
			"メニュー編集"
		end
		
		def body
			model = amrita_default_model
			
			model[:direct] = @context.route_to('/master_menu/menu_edit_form/direct')
			
			rows = []
			
			list = [MenuItem::Top, MenuItem::About, MenuItem::Recent, MenuItem::EntryList, MenuItem::Search, MenuItem::NewsFeed, MenuItem::MasterMenu]
			
			DEFAULT_MENU_KEYS.each_with_index do |key, i|
				item_cls = list[i]
				item = config.menu.items.find{|x| x.kind_of?(item_cls)}
				
				default_caption = key.tr('_', ' ')
				row = {}
				unless key.in?(REQUIRED_MENU_KEYS) then
					row[:checkbox] = {:name => "#{key}_visible", :checked => (item ? 'checked' : nil)}
				end	
				row[:caption_name] = "#{key}_caption"
				row[:caption_value] = (item ? item.caption : default_caption)
				row[:default] = default_caption
				
				rows << row
			end
			
			model[:menu_form_rows] = rows
			
			return expand_amrita_template("menu_edit_form.html", model)
		end
	end
	
	class DirectMenuEditFormSection < Section
		require_opt :menu_text

		def header_text
			"メニュー編集"
		end
		
		def body
			model = amrita_default_model
			
			model[:basic] = @context.route_to('/master_menu/menu_edit_form/simple')
			model[:menu_text] = @menu_text || DEFAULT_MENU_TEXT
			
			return expand_amrita_template("direct_menu_edit_form.html", model)
		end
	end
	
	class MenuCommandListSection < Section
		def header_text
			"メニューコマンド一覧"
		end
		
		def body
			return expand_amrita_template("menu_command_list.html", {})
		end
	end



	
	class PostLimitFormSection < Section

		def header_text
			"投稿制限"
		end
		
		def body
			model = amrita_default_model
			

			[:message_length, :comment_length].each do |sym|
				model[sym] = {}
				model[sym][:tight_length] = LIMIT_TABLE[sym]['tight']
				model[sym][:loose_length] = LIMIT_TABLE[sym]['loose']
				model[sym][:very_loose_length] = LIMIT_TABLE[sym]['very-loose']
				
				case config.send("#{sym}_limit")
				when 'very-loose'
					model[sym][:very_loose_checked] = 'checked'
				when 'tight'
					model[sym][:tight_checked] = 'checked'
				else
					model[sym][:loose_checked] = 'checked'
				end
			end
			
			model[:block_http] = 'checked' if config.block_http
			model[:block_ascii] = 'checked' if config.block_ascii
			
			model[:ng_word] = config.ng_words.join("\r\n")


		
			
			return expand_amrita_template("post_limit_form.html", model)
			
		end
	end
	
	class MailNotificationConfigFormSection < Section

		def header_text
			"メール通知設定"
		end
		
		def body
			model = amrita_default_model
			

			model[:sendmail_path] = config.sendmail_path
			model[:to_1] = config.mail_notification_to_addresses[0] || ''
			model[:to_2] = config.mail_notification_to_addresses[1] || ''
			model[:to_3] = config.mail_notification_to_addresses[2] || ''
			
			return expand_amrita_template("mail_notification_config_form.html", model)
			
		end
	end


	
	
	class RefererTableSection < Section
		require_opt :table

		def header_text
			"現在のURL置換リスト"
		end
		
		def body
			model = amrita_default_model
			model[:list] = []
			@table.each do |url, name|
				model[:list] << {:url => url, :name => (name == '-' ? '(非表示)' : name)}
			end
			
			return expand_amrita_template("referer_table.html", model)
			
		end
	end
	
	class RefererTableEditFormSection < Section
	
		require_opt :table_text
		
		def header_text
			"URL置換リストの編集"
		end
		
		def body
			model = amrita_default_model
			model[:table] = @table_text
			
			return expand_amrita_template("referer_table_edit_form.html", model)
			
		end
	end
	

	class HTMLCustomizeFormSection < Section
		def header_text
			"HTMLカスタマイズ"
		end
		
		def body
			model = amrita_default_model
			
			[:head, :kizi_foot, :body_foot].each do |id|
				model[id] = @custom_html[id] || ''
			end
			
			model[:extra_address_rows] = []
			EXTRA_ADDRESS_NUMBER.times do |i|
				address_data = config.extra_addresses[i]
				model[:extra_address_rows] << {
					:caption_name => "extra_address_caption#{i}",
					:caption_value => (address_data ? address_data['caption'] : nil),
					:href_name => "extra_address_href#{i}",
					:href_value => (address_data ? address_data['href'] : nil),
				}
			end
			
		
			return expand_amrita_template("html_customize_form.html", model)
			
		end
	end

	
	class EntryDataListSection < Section
		require_opt :entries, :access_record, :file_data

		def initialize(context, option_args = {})
			super(context, option_args)
			@file_data[:size] ||= {}
		end
		
		def entry_rows
			model = []
			@entries.each do |entry|
				checked = !((entry.tags & request.tags).empty?)
				model << {
					:id => entry.id,
					:last_modified => @context.time2str_short(entry.last_modified),
					:href => @context.route_to("entries/#{entry.id}"),
					:caption => entry.title_caption,
					:size => Util.size_to_kb(@file_data[:size][entry.id]),
					:access => (@access_record['counts'][entry.id] || 0).to_i,
					:comment => (entry.commentable? ? entry.existing_comments.size : '-'),
					:checked => (checked ? 'checked' : ''),
				}
				
				images = @attached_image_table[entry.id]
				unless images.empty? then
					attached_byte = images.map{|x| x.file_size}.total
					model.last[:attached_size] = Util.size_to_kb(attached_byte)
				end
				
				model.last[:tags] = []
				entry.tags.each do |tag|
					query = Util.tags_to_query([tag])
					model.last[:tags] << {:href => @context.route_to("master_menu/entry_manager", query), :name=> tag}
				end
			end
			return model
		end
	end
	
	class EntryManagerSection < EntryDataListSection

		def header_text
			"記事の管理・一括操作"
		end
		
		def body
			
			model = amrita_default_model
			@entries.sort!{|a,b| b.last_modified <=> a.last_modified}
			model[:rows] = entry_rows
			return expand_tenjin_template("entry_manager.rbhtml", model)
		end
	end
	


	class EntryDeleteConfirmationSection < EntryDataListSection
		require_opt :attached_image_table
	
		def header_text
			"記事の削除確認"
		end
		
		def body
			
			model = amrita_default_model
			@entries.sort!{|a,b| b.last_modified <=> a.last_modified}
			model[:rows] = entry_rows
			return expand_tenjin_template("entry_delete_confirmation.rbhtml", model)
		end
	end


	class EntryTimestampChangeFormSection < Section
		require_opt :entries
	
		def header_text
			"作成/更新日時の変更"
		end
		
		def body
			
			model = amrita_default_model
			model[:entries] = @entries
			model[:context] = @context
			return expand_tenjin_template("entry_timestamp_change_form.rbhtml", model)
		end
	end

	
	
	
	
	
	class SearchFormSection < Section
	
		require_opt :keywords

		def header_text
			"blog内の記事を検索"
		end
		
		def body
			expand_amrita_template("search_form.html", {:action => @context.route_to('search'), :keyword => @keywords.join(' ')})
		end
	end
	
	class SearchResultSection < Section
		require_opt :keywords, :hit_list
		
	
		def header_text
			"検索結果"
		end
		
		def body
			model = amrita_default_model
			model[:info] = @keywords.map{|x| "「#{x}」"}.join + "で検索し、#{@hit_list.size}記事が見つかりました"
			model[:items] = []
			@hit_list.each do |entry, hits, score|
				model[:items] << {:caption => entry.title_caption, :href => @context.route_to("entries/#{entry.id}")}
				hit_list = []
				hit_list << "スコア:#{score}"
				hit_list += hits.map{|x| x.to_s}

				
				model[:items] << {:hit_list => hit_list}
				
			end
			expand_amrita_template("search_result.html", model)
		end
	end

	
	class LoginFormSection < Section
		def header_text
			"管理者パスワード入力"
		end
		
		def body
			expand_amrita_template("login_form.html", amrita_default_model.merge(:auto_login => (config.auto_login? && 'checked')))
		end
	end

	class ImportFormSection < Section
		require_opt :zlib_installed
		def header_text
			"インポート"
		end
		
		def body
			model = amrita_default_model
			if @zlib_installed then
				model[:zlib_installed] = {}
			else
				model[:zlib_not_installed] = {}
			end		
			
			return expand_amrita_template("import_form.html", model)
			
		end
	end
	

	class ImportEntrySelectFormSection < Section
		require_opt :new_entry_data, :overlap_entry_data, :format

		def header_text
			"インポートする記事の選択"
		end
		
		def body
			model = amrita_default_model
			model[:format] = @format
			model[:new_entry_data] = @new_entry_data
			model[:overlap_entry_data] = @overlap_entry_data
			model[:image_sizes] = @image_sizes
			model[:image_numbers] = @image_numbers
			
			return expand_tenjin_template("import_entry_select_form.rbhtml", model)
			
		end
	end


	
	class ExportFormatSelectSection < Section	
		def header_text
			"エクスポート"
		end
		
		def body
			model = amrita_default_model
			model[:mt_compatible] = @context.route_to('/master_menu/export/mt-compatible')
			model[:pblog] = @context.route_to('/master_menu/export/pblog')
			return expand_amrita_template("export_format_select.html", model)
			
		end
	end
	
	class ExportByMTCompatibleFormSection < Section
		def header_text
			'MovableType互換形式で出力'
		end
		
		def body
			model = amrita_default_model
			model[:default_file_name] = 'mtlog.txt'
			model[:format] = 'mt-compatible'
			model[:encoding] = {}		
			model[:mt_caution] = {}		
			
			return expand_amrita_template("export_form.html", model)
			
		end
	end
	
	class ExportByPblogFormSection < Section
		require_opt :zlib_installed
	
		def header_text
			'pblog形式で出力'
		end
		
		def body
			model = amrita_default_model
			model[:default_file_name] = 'pblog.yml'
			model[:format] = 'pblog'
			if @zlib_installed then
				model[:compressing] = {:zlib_installed => {}}
			else
				model[:compressing] = {:zlib_not_installed => {}}
			end		
			
			return expand_amrita_template("export_form.html", model)
			
		end
	end


	class ExportResultSection < Section
		def header_text
			'完了'
		end
		
		def body
			model = amrita_default_model
			model[:file_name] = @file_name
			model[:file_href] = @context.file_route_to(config.res_dir_path + 'temp/' + @file_name)
			model[:file_size] = @file_size
			model[:time] = sprintf('%.2f秒', @time)
			model[:entry_number] = @entry_number
			model[:master_menu_href] = @context.route_to('/master_menu')
			
			return expand_amrita_template("export_result.html", model)
			
		end
	end

	
	class SnapshotSection < Section
		require_opt :entries
	
		def header_text
			"スナップショット"
		end
		
		def body
			model = amrita_default_model
			
			
			rows = []
			SNAPSHOT_MENU_KEYS.each_with_index do |key, i|
				default_caption = key.tr('_', ' ')
				row = {}
				unless key.in?(SNAPSHOT_REQUIRED_MENU_KEYS) then
					row[:checkbox] = {:name => "#{key}_visible", :checked => 'checked'}
				end	
				row[:caption_name] = "#{key}_caption"
				row[:caption_value] = default_caption
				row[:default] = default_caption
				
				rows << row
			end
			
			model[:spans] = []
			model[:spans] << {:value => 'all', :caption => "すべての公開記事を出力 (#{@entries.size})"}
			
			month_table = {}
			@entries.each do |entry|
				code = sprintf("month-%04d-%02d", entry.created.year, entry.created.month)
				month_table[code] ||= []
				month_table[code] << entry
			end
			month_table.to_a.sort{|a, b| a[0] <=> b[0]}.each do |code, entries|
				type, y, m = code.split('-')
				model[:spans] << {:value => code, :caption => "#{y.to_i}年#{m.to_i}月作成の公開記事を出力 (#{entries.size})"}
			end
			
			tag_table = {}
			@entries.each do |entry|
				entry.visible_tags.each do |tag|
					tag_table[tag] ||= []
					tag_table[tag] << entry
				end
			end
			tag_table.to_a.sort{|a, b| a[0] <=> b[0]}.each do |tag, entries|
				value = "tag-#{Util.encode_base64url(tag)}"
				model[:spans] << {:value => value, :caption => "タグ「#{tag}」を含む公開記事を出力 (#{entries.size})"}
			end

			
			
			model[:menu_form_rows] = rows
			expand_amrita_template("snapshot.html", model)
		end
	end
	
	class SnapshotResultSection < Section
		def header_text
			'完了'
		end
		
		def body
			model = amrita_default_model
			model[:file_href] = model[:file_href_by_blank] = @context.file_route_to('snapshot')
			model[:total_file_size] = @total_file_size
			model[:total_file_number] = @total_file_number
			model[:time] = sprintf('%.2f秒', @time)
			model[:master_menu_href] = @context.route_to('/master_menu')
			
			return expand_amrita_template("snapshot_result.html", model)
			
		end
	end


	
	class NewsFeedSection < Section
		def header_text
			"ニュースフィード配信"
		end
		
		
		def body
			
			model = amrita_default_model
			
			%w(created modified comment).each do |name|
				if (config.feed_dir_path + "#{name}.xml").exist? then
					model[name.to_sym] = {:url => @context.get_feed_url("#{name}.xml")}
				else
					model[name.to_sym] = "（まだフィードが作成されていません）"
				end
			end

			uri = @context.file_route_to(config.res_dir_path + 'pinkyblog/atom10.png')
			model[:atom10_img] = Amrita.a({:src => uri.to_s})
			expand_amrita_template("news_feed.html", model)
		end
	end

	
end
