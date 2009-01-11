# ひとことメッセージを表すクラス
require 'md'
require 'uuidtools'



module PinkyBlog
	class Message
		attr_accessor :time, :content, :read, :uuid
		alias read? read
		
		def initialize(time, content, read = false)
			@time = time
			@content = content
			@read = read
			@uuid = UUID.random_create.to_s
		end
		
		
		
		def to_md_track
			track = MD::Track.new
			track.type = 'PinkyBlog/Message'
			track.headers['Time'] = @time.to_i.to_s
			track.headers['Read'] = @read.to_s
			track.headers['UUID'] = @uuid

			track.body = @content
			return track
		end
		
		
		def build_from_md_track(track)
			@time = Time.at(track.headers['Time'].to_i)
			@content = track.body
			@read = (track.headers['Read'] == 'true')
			@uuid =  track.headers['UUID']
			return self
		end
		
		def Message.build_from_md(md)
			messages = md.tracks.find_all{|x| x.type == 'PinkyBlog/Message'}
			return messages.map{|x| Message.new(nil, nil).build_from_md_track(x)}
		end

	end
end
