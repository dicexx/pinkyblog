#-> Entry, Comment
require 'uuidtools'
require 'md'
require 'digest/md5'

require 'pinkyblog/const'
require 'pinkyblog/util'

module PinkyBlog

	# 記事を表すクラス
	class Entry
	
		attr_accessor :id, :content, :last_modified, :created, :title
		attr_accessor :visible, :edited_number, :format, :attached_image_display
		alias updated last_modified
		alias updated= last_modified=
		alias body content
		alias body= content=
		alias visible? visible
		
		def initialize(id, args = {})
			@id = id
			@title = args[:title] || ""
			@content = args[:content] || ""
			@last_modified = args[:last_modified] || Time.now
			@created = args[:created] || Time.now
			@visible = args[:visible] || false
			@edited_number = args[:edited_number] || 0
			@format = args[:format] || nil
			@attached_image_display = args[:attached_image_display] || ID::DEFAULT
		end
		

		
		def invisible?
			!(self.visible?)
		end
		
		def title_caption
			return nil unless self.title
			(@visible ? self.title : "(非公開) " + self.title)
		end
		
		def commentable?
			false
		end
		
		
		def tags
			[]
		end
		
		def normal_tags
			tags - special_tags
		end
		alias visible_tags normal_tags
		
		def special_tags
			tags.find_all{|x| x =~ SPECIAL_TAG_BASE_PATTERN}
		end
		alias invisible_tags special_tags
		
		
		def find_special_tag(id)
			special_tags.find{|x| x =~ SPECIAL_TAG_NAME_PATTERNS[id]}
		end

		# generate ETag
		def etag
			Digest::MD5.hexdigest(etag_base)
		end
		
		def etag_base
			"#{@id} #{@title} #{@created.to_i} #{@last_modified.to_i} #{@edited_number} \
			 #{@format} #{@attached_image_display} #{@content.length} "
		end
		
		
		def build_from_md(md)
			track = md[0]
			@title = track.headers['Title']
			if @title then
				@title.strip!
			end
			@created = Time.at(track.headers['Created'].to_i)
			@visible = (track.headers['Visible'] == 'true')
			@last_modified = Time.at(track.headers['Last-Modified'].to_i)
			@edited_number = track.headers['Edited-Number'].to_i
			@format = track.headers['Format']
			@content = track.body
			@attached_image_display = track.headers['Attached-Image-Display'] || ID::DEFAULT

			return self
		end
		
		
		def to_md
			headers = {}
			headers['Title'] = @title
			headers['Visible'] = @visible.to_s
			headers['Created'] = @created.to_i
			headers['Last-Modified'] = @last_modified.to_i
			headers['Edited-Number'] = @edited_number
			headers['Format'] = @format
			headers['Attached-Image-Display'] = @attached_image_display
			
			return MD.new([MD::Track.new(headers, @content)])
		end
		
		

		
		
		
		def Entry.get_file_path(dir_path, prefix, id)
			file_name = "#{prefix}_#{id}.md"
			path = Pathname.new(dir_path) + file_name
			return path
		end
		
		def Entry.create_new_id(base_time = Time.now)
			extend = sprintf("%04x", rand(16 * 16 * 16 * 16))
			"#{base_time.to_i}-#{extend}"
		end

		def Entry.load(dir_path, prefix, id)
			return Entry.new(id).load(dir_path, prefix)
		end
		
		def Entry.build_from_md(id, md)
			if Util.static_entry_id?(id) then
				return StaticEntry.new(id).build_from_md(md)
			else
				return BasicEntry.new(id).build_from_md(md)
			end
		end
	end
	
	class BasicEntry < Entry
		attr_accessor :comments, :tags, :uuid
		def initialize(id = Entry.create_new_id, args = {})
			super
			@comments = args[:comments] || []
			@tags = args[:tags] || []
			@uuid = UUID.random_create.to_s
		end
		
		def existing_comments
			@comments.find_all{|x| !(x.deleted?)}
		end
		
		def etag_base
			comment_data = @comments.map{|x| x.content.length}.join(' ')
			return(super + "#{@comments.size} #{comment_data} #{@tags.join(' ')} ")
		end

		def build_from_md(md)
			super
			
			@tags = md[0].headers['Tags'].split(' ')
			@uuid = md[0].headers['UUID']
			
		
			@comments.clear
			md.tracks.find_all{|x| x.type == 'PinkyBlog/Comment'}.each do |track|
				@comments << Comment.new(nil, nil, nil).build_from_md_track(track)
			end
			return self
		end
		
		def commentable?
			!(find_special_tag(:uncommentable))
		end


		
		def to_md
			md = super
			md[0].type = 'PinkyBlog/BasicEntry'
			md[0].headers['Tags'] = @tags.join(' ')
			md[0].headers['UUID'] = @uuid
			
			@comments.each do |comment|
				md.tracks << comment.to_md_track
			end
			return md
		end
	end
	
	class StaticEntry < Entry
		
		def title
			@title || default_title
		end
		
		def default_title
			STATIC_ENTRY_DEFAULT_TITLES[@id]
		end
		
		def comments
			[]
		end
		
		
		def to_md
			md = super
			md[0].type = 'PinkyBlog/StaticEntry'
			return md
		end

		

	end
	

	# 記事につけられたコメントを表すクラス
	class Comment
		attr_accessor :writer, :content, :time, :mail_address, :password_sha, :edited_number, :uuid
		bool_attr_accessor :deleted
		
		alias body content
		alias body= content=
		
		def initialize(writer, content, mail_address, password_sha = nil, time = Time.now)
			@writer = writer
			@content = content
			@mail_address = mail_address
			@time = time
			@uuid = UUID.random_create.to_s
			@password_sha = password_sha
			@edited_number = 0
			@deleted = false
		end
		
		def delete
			@deleted = true
		end
		
		def content_html
			Util.escape_html(@content).split(/\r?\n/).join("<br>\n")
		end
		
		
		def to_md_track
			track = MD::Track.new
			track.type = 'PinkyBlog/Comment'
			if @deleted then
				track.headers['Deleted'] = true
			else
				track.headers['Writer'] = @writer if @writer
				track.headers['Time'] = @time.to_i.to_s
				track.headers['Mail-Address'] = @mail_address if @mail_address
				track.headers['UUID'] = @uuid
				track.headers['Password-SHA'] = @password_sha if @password_sha
				track.headers['Edited-Number'] = @edited_number

				track.body = @content
			end
			return track
		end
		
		
		def build_from_md_track(track)
			track.type = 'PinkyBlog/Comment'
			@writer = track.headers['Writer']
			@time = Time.at(track.headers['Time'].to_i)
			@mail_address = track.headers['Mail-Address']
			@uuid =  track.headers['UUID'] || UUID.random_create.to_s
			@password_sha =  track.headers['Password-SHA']
			@edited_number =  track.headers['Edited-Number'].to_i if track.headers['Edited-Number']
			@deleted =  (track.headers['Deleted'] == 'true')
			@content = track.body
			return self
		end

		
		

	end

end
