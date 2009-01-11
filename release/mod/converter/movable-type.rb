# encoding: utf-8

require 'stringio'

SEPARATOR_PATTERN = /^\s*-----$/
ENTRY_SEPARATOR_PATTERN = /^\s*--------$/
METADATA_PATTERN = /^(.+?)\: (.+)$/


Entry = Struct.new(:metadata, :fields)
Field = Struct.new(:metadata, :body)

class Converter
	def import(api, text)
		lines = text.split("\n")
		
		
		entries = []

		loop do
			entry = Entry.new({}, {})
			
			# メタデータ読み込み
			while (line = lines.shift) do
				case line
				when SEPARATOR_PATTERN
					break
				when METADATA_PATTERN
					entry.metadata[$1.downcase] = $2
				else
	
				end
			end
			
			
			# 複数行フィールド
			while (line = lines.shift) do
				case line
				when /^(.+?)\:\s*$/
					sect = $1.downcase
					entry.fields[sect] = Field.new({}, '')
		
					# フィールド内メタデータ読み込み
					while lines.first =~ METADATA_PATTERN do
						entry.fields[sect].metadata[$1.downcase] = $2
						lines.shift
					end
					
					# 本文読み込み
					while (line = lines.shift) do
						case line
						when SEPARATOR_PATTERN
							break
						else
							entry.fields[sect].body << line
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
		end
	end

	def export(api, entries)
		buf = StringIO.new
		
		entries.each do |entry|
			# メタデータ
			buf.puts "TITLE: #{entry.title}"
			buf.puts "DATE: #{format_time(entry.created)}"
			#buf.puts "AUTHOR: #{}"
			entry.tags.each do |tag|
				buf.puts "CATEGORY: #{tag}"
			end
			buf.puts "STATUS: #{(entry.visible? ? 'Publish' : 'Draft')}"
			#buf.puts "ALLOW COMMENTS: #{(entry.tags.include?('！コメント不可') ? '0' : '1')}"
			buf.puts "CONVERT BREAKS: 0"
			buf.puts "-----"
			
			# 記事本文
			buf.puts 'BODY:'
			buf.puts api.translate(entry.body)
			buf.puts "-----"

			# コメント
			entry.comments.each do |comment|
				buf.puts 'COMMENT:'
				buf.puts "AUTHOR: #{comment.writer}" if comment.writer
				buf.puts "EMAIL: #{comment.mail_address}" if comment.mail_address
				buf.puts "DATE: #{format_time(comment.time)}"
				buf.puts api.translate(entry.body)
				buf.puts "-----"
			end
			
			buf.puts "--------"

		end
	end
	
	private
	def format_time(time)
		time.strftime('%m/%d/%Y %H:%M:%S')
	end
end

p Converter.new.import(nil, $stdin.read)