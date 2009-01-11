#-------------------------------------------------------------------------------
# MD (Mini Data format) Library
#
# requirement: ruby 1.8.0 later
# author: Dice <scl@dc.littlestar.jp>
# last update: 2008-09-13
# license: Public Domain (unlike other files)
#-------------------------------------------------------------------------------
require 'stringio'

class MD
	HEADER_PATTERN = /^(.+?)\s*\:\s*(.+)$/

	SEPARATOR = "."
	HEADER_SEQUEL_PATTERN = /^\s+(.+)$/
	
	SEPARATOR_PATTERN = /^[.]$/
	ESCAPING_REQUIRED_PATTERN = /^[.]{1,}$/
	ESCAPED_SEPARATOR_PATTERN = /^[.]{2,}$/
	VERSION_PATTERN = /\[MD\/(.+)\]/
	attr_accessor :tracks, :version


	class Track
	
		attr_accessor :headers, :body
		def initialize(headers = {}, body = "")
			@headers = headers
			@body = body
		end
		
		def type
			@headers['Type']
		end
		
		def type=(value)
			@headers['Type'] = value
		end
		
		def has_header?(key)
			@headers.has_key?(key)
		end
		alias include? has_header?

		
	
		def to_s
			str = ""
			@headers.each_pair do |key, value|
				value = value.to_s.gsub("\n", "\n\t")
				str << "#{key}: #{value}\n"
			end
			str << "\n" # blank line
			str << MD.escape_separator(@body)
			str << "\n#{SEPARATOR}"
			return str
		end
	end



	def initialize(tracks = [], version = nil)
		@tracks = tracks
		@version = "0.1"
	end

	def [](index)
		@tracks[index]
	end
	
	def []=(index, track)
		@tracks[index] = track
	end
	
	
	
	def to_s
		
		return "[MD/#{@version}]\n" + @tracks.map{|x| x.to_s}.join("\n")
	end

	def find_type(type)
		@tracks.find{|x| x.type == type}
	end

	def save
		open(@path, 'w'){|f| f.write(self.to_s)}
		return self
	end

	
	
	


	def self.parse(md_text)
		raise MDError, "can't parse nil." unless md_text
		md = MD.new
		
		md_text.gsub!(/\r\n|\r/, "\n")
		input = StringIO.new(md_text)
		
		version = get_version(input)
		if version then
			md.version = version
			until input.eof? do
				md.tracks << get_track(input)
			end
			md.tracks.compact!

			
			return md
		else
			return nil
		end

	end
	
	def self.get_track(input)
		headers = get_headers(input)
		body = get_body(input)
		if !(headers.empty?) || body then
			return Track.new(headers, body)
		else
			return nil
		end
	end

	def self.load(path)
		return self.new(path).load
	end



	def self.get_version(input)
		line = input.gets
		if line =~ VERSION_PATTERN then
			return $1
		else
			return nil
		end
	end

	def self.get_headers(input)
		headers = {}

		latest = nil
		while (line = input.gets) && !(line.chomp.empty?) do
			case line
			when HEADER_SEQUEL_PATTERN
				raise MDParseError, "header parse failed. (#{input.path}:#{input.lineno})" unless latest
				latest << $1
			when HEADER_PATTERN
				headers[$1] = $2
				latest = headers[$1]
			else
				raise MDParseError, "header parse failed. (#{input.path}:#{input.lineno}) <#{line.inspect}>"
			end
		end

		return headers
	end

	def self.get_body(input)
		body = ""

		latest = nil
		loop do
			line = input.gets
			if line =~ SEPARATOR_PATTERN then
				break
			elsif line then
				# succed gets
				body << unescape_separator(line.chomp) << "\n"
			else
				# eof
				return nil
			end
		end
		
		body.chomp!
		return body
	end



	def self.escape_separator(str)
		return str.gsub(ESCAPING_REQUIRED_PATTERN){".#{$~.to_s}"}
	end

	def self.unescape_separator(str)
		return str.gsub(ESCAPED_SEPARATOR_PATTERN){$~.to_s[1..-1]}
	end

end

class MDError < StandardError; end
class MDParseError < MDError; end
