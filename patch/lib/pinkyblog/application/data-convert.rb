# encoding: utf-8

require 'kconv'
require 'stringio'
require 'yaml'
require 'ya2yaml'
require 'pinkyblog/application/core'

module PinkyBlog
	class Application

		module Log
			def self.guess_format(basename, body)
				# まずは拡張子で調べる
				case basename
				when /\.(?:yml|yaml)\.gz$/
					return LF::PBLOG_GZIP
				when /\.(?:yml|yaml)$/
					return LF::PBLOG
				when /\.txt$/
				
					# ruby 1.8.1 以前では未定義の定数
					ascii_kcode = (defined?(Kconv::ASCII) ? Kconv::ASCII : Kconv::BINARY)
					utf8_kcode = (defined?(Kconv::UTF8) ? Kconv::UTF8 : Kconv::BINARY) 
					kcode = Kconv.guess(body)
					
					case kcode
					when utf8_kcode, ascii_kcode
						return LF::MT_COMPATIBLE_UTF8
					when Kconv::SJIS
						return LF::MT_COMPATIBLE_SJIS
					when Kconv::EUC
						return LF::MT_COMPATIBLE_EUC
							
					else
						return nil
					end
				else
					return nil
				end
			end
		
			module MTCompatible
				SEPARATOR_PATTERN = /^\s*-----$/
				ENTRY_SEPARATOR_PATTERN = /^\s*--------$/
				METADATA_PATTERN = /^(.+?)\: (.+)$/
				
				
				Entry = Struct.new(:metadata, :categories, :body_field, :extended_body_field, :comment_fields)
				Field = Struct.new(:metadata, :body)
		
				# 改行コードが\nであることを前提としている
				def self.import(text)
					lines = text.split("\n")
					
					
					entries = []
			
					loop do
						entry = Entry.new({}, [], nil, nil, [])
						
						# メタデータ読み込み
						while (line = lines.shift) do
							case line
							when SEPARATOR_PATTERN
								break
							when METADATA_PATTERN
								if $1.downcase == 'category' or $1.downcase == 'primary category' then
									entry.categories << $2
								else
									entry.metadata[$1.downcase] = $2
								end
							else
				
							end
						end
						
						
						# 複数行フィールド
						while (line = lines.shift) do
							case line
							when /^(.+?)\:\s*$/
								sect = $1.downcase
								field = Field.new({}, '')
								
								case sect
								when 'body'
									entry.body_field = field
								when 'extended body'
									entry.extended_body_field = field
								when 'comment'
									entry.comment_fields << field
									# フィールド内メタデータ読み込み
									while lines.first =~ METADATA_PATTERN do
										field.metadata[$1.downcase] = $2
										lines.shift
									end
								else
									# 未知の複数行フィールドは無視される
								end
								

								# ボディ読み込み
								while (line = lines.shift) do
									case line
									when SEPARATOR_PATTERN
										field.body.chomp!
										break
									else
										field.body << line << "\n"
									end
								end
					
							when ENTRY_SEPARATOR_PATTERN
								break
							else
							end
						end
						
						entries << entry
						
						# すべて読み込み終わったか、残りの行がすべて空行なら終了
						if lines.empty? or lines.all?{|x| x =~ /^\s*$/} then
							return entries
						end
					end # of loop
				end # of import
			
			
				
				def self.export(entries, module_handler)
					buf = StringIO.new
					
					entries.each do |entry|
						# メタデータ
						buf.puts "TITLE: #{entry.title}"
						buf.puts "BASENAME: pb_#{entry.id}"
						buf.puts "DATE: #{format_to_date(entry.created)}"
						#buf.puts "AUTHOR: #{}"
						entry.normal_tags.each do |tag|
							buf.puts "CATEGORY: #{tag}"
						end
						buf.puts "STATUS: #{(entry.visible? ? 'Publish' : 'Draft')}"
						buf.puts "ALLOW COMMENTS: #{entry.tags.include?('！コメント不可') ? '0' : '1'}"
						buf.puts "CONVERT BREAKS: 0"
						buf.puts "-----"
						
						# 記事本文
						buf.puts 'BODY:'
						buf.puts module_handler.translate(entry.format, entry.content)
						buf.puts "-----"
			
						# コメント
						entry.existing_comments.each do |comment|
							buf.puts 'COMMENT:'
							buf.puts "AUTHOR: #{comment.writer}" if comment.writer
							buf.puts "EMAIL: #{comment.mail_address}" if comment.mail_address
							buf.puts "DATE: #{format_to_date(comment.time)}"
							buf.puts comment.content
							buf.puts "-----"
						end
						
						buf.puts "--------"
			
					end
					
					return buf.string
				end
				

				def self.format_to_date(time)
					time.strftime('%m/%d/%Y %H:%M:%S')
				end
				
				def self.parse_date(timestr)
  				if timestr =~ /^\s*(\d+)\/(\d+)\/(\d+)\s+(\d+)\:(\d+)\:(\d+)(?:\s+(AM|PM))?\s*$/ then
						mon, day, year, hour, min, sec = $~.captures[0..5].map{|x| x.to_i}
						if $7 == 'PM' then
							hour += 12
						end
						return Time.local(year, mon, day, hour, min, sec)
					end
				end
				
				# 改行コードが\nであることを前提としている
				def self.entry_to_pb_entry(src)
					date = parse_date(src.metadata['date'])
					basename = src.metadata['basename']
					
					re = nil
					if basename and basename =~ /^pb_(.+)$/ then
						id = $1
						if Util.validate_entry_id(id) then
							re = BasicEntry.new(id)
						end
					end
					re ||= BasicEntry.new(Entry.create_new_id(date))
					
					
					# 各種メタデータ
					re.title = src.metadata['title']
					
					if src.metadata.include?('status') then
						re.visible = src.metadata['status'].downcase == 'publish'
					else
						re.visible = true
					end
					re.updated = date
					re.created = date
					re.tags = src.categories.uniq
					re.format = 'html'
					
					# 本文
					if src.extended_body_field then
						re.content = src.body_field.body + "\n\n" + src.extended_body_field.body
					else
						re.content = src.body_field.body
					end
					
					case src.metadata['convert breaks']
					when '1'
						re.content.gsub!("\n", '<br>')
					end

					# コメント
					src.comment_fields.each do |field|
						c = Comment.new(field.metadata['author'], field.body, field.metadata['email'])
						c.time = parse_date(field.metadata['date'])
						re.comments << c
					end
					
					re
				end

			end # of MTCompatible
	

			module Pblog
				def self.import_from_io(io)
					docs = []
					YAML.each_document(io){|doc|
						docs << doc
					}
					
					docs.shift
					entries = []
					access_data = {'referers' => {}, 'counts' => {}}
					image_data = []
					docs.each do |doc|
						entry = BasicEntry.new(doc['ID'])
						entry.title = doc['Title']
						entry.visible = doc['Visible']
						entry.uuid = doc['UUID']
						entry.body = doc['Body']
						entry.format = doc['Format']
						entry.updated = doc['Updated']
						entry.created = doc['Created']
						entry.attached_image_display = doc['Attached-Image-Display']
						entry.tags = doc['Tags']
						entry.comments = doc['Comments'].map do |data|
							c = Comment.new(data['Writer'], data['Body'], data['Mail-Address'])
							c.uuid = data['UUID']
							c.time = data['Time']
							c.password_sha = data['Password-SHA']
							c.edited_number = data['Edited-Number']
							c.deleted = data['Deleted']
							
							c
						end
						

						entries << entry
						
						access_data['referers'][entry.id] = doc['Referers']
						access_data['counts'][entry.id] = doc['Access-Count']
						image_data << doc['Images']

					end
					
					return [entries, access_data, image_data]
				end
				
				def self.import(yaml)
					import_from_io(StringIO.new(yaml))
				end
			
				def self.export_to_io(io, entries, config, access_data, image_table)
					metadata = {}
					metadata['Type'] = 'pblog'
					metadata['Version'] = 1.0
					io << metadata.ya2yaml
						
							
					entries.each do |entry|
						data = {}
						data['Title'] = entry.title
						data['Visible'] = entry.visible
						data['ID'] = entry.id
						data['UUID'] = entry.uuid
						data['Body'] = entry.content
						data['Format'] = entry.format
						data['Updated'] = entry.last_modified
						data['Created'] = entry.created
						data['Tags'] = entry.tags
						data['Attached-Image-Display'] = entry.attached_image_display
						data['Access-Count'] = access_data['counts'][entry.id] || 0
						data['Referers'] = access_data['referers'][entry.id] || {}
		
								
						data['Images'] = []
						image_table[entry.id].each do |image|
							path = config.attached_dir_path + "#{entry.id}_#{image.name}"
							body = nil
							open(path, 'rb'){|f| body = f.read}
								
							data['Images'] << {'Name' => image.name, 'Body' => [body].pack('m*')}
						end
								
						data['Comments'] = []
						entry.comments.each do |comment|
							data['Comments'] << {
								'Body' => comment.content,
								'Mail-Address' => comment.mail_address,
								'Writer' => comment.writer,
								'Time' => comment.time,
								'UUID' => comment.uuid,
								'Edited-Number' => comment.edited_number,
								'Password-SHA' => comment.password_sha,
								'Deleted' => comment.deleted?,
							}
						end
						io << data.ya2yaml
					end
								
					
				end
			
			
				def self.export(entries, config, access_data, image_table)
					re = ''
					export_to_io(re, entries, config, access_data, image_table)
				
					return re
				end
			end # of Pblog
		end # of Log
	end # of Application
end # of PinkyBlog