#-----------------------------------------------------------
# markdown トランスレータ for Pinky:blog
#
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/
#
# ただし、このファイルから呼び出している bluecloth.rb は
# GPL (General Public License) に従います。
# 詳しくは bluecloth.rb 内にある著作権表示をご覧ください。
#-----------------------------------------------------------


CAPTION = "Markdownで書く"

require (DIR_PATH + 'bluecloth').to_s

class Translator
	def text_to_html(text)
		return BlueCloth.new(text).to_html
	end
	
	def format_guide
		(DIR_PATH + 'guide.txt').read
	end
end


# patch for Pinky:blog
class BlueCloth < ::BlueCloth
	
	def transform_headers( str, rs )
		@log.debug " Transforming headers"

		# Setext-style headers:
		#	  Header 1
		#	  ========
		#  
		#	  Header 2
		#	  --------
		#
		str.
			gsub( SetextHeaderRegexp ) {|m|
				@log.debug "Found setext-style header"
				title, hdrchar = $1, $2
				title = apply_span_transforms( title, rs )

				case hdrchar
				when '='
					%[<h3>#{title}</h3>\n\n]
				when '-'
					%[<h4>#{title}</h4>\n\n]
				else
					title
				end
			}.

			gsub( AtxHeaderRegexp ) {|m|
				@log.debug "Found ATX-style header"
				hdrchars, title = $1, $2
				title = apply_span_transforms( title, rs )

				level = hdrchars.length
				%{<h%d>%s</h%d>\n\n} % [ level + 2, title, level + 2 ]
			}
	end
	
	# Pattern to match strong emphasis in Markdown text
	JBoldRegexp = %r{ (\*\*|__) (.+?) \1 }x

	# Pattern to match normal emphasis in Markdown text
	JItalicRegexp = %r{ (\*|_) (.+?) \1 }x

	# 二文字のフレーズに正しくマッチしないバグを修正
	def transform_italic_and_bold( str, rs )

		str.
			gsub( JBoldRegexp, %{<strong>\\2</strong>} ).
			gsub( JItalicRegexp, %{<em>\\2</em>} )
	end
	
	# 日本語修正: ひとつの段落内の各行を、完全に（改行文字を入れずに）結合する
	def form_paragraphs( str, rs )
		@log.debug " Forming paragraphs"
		grafs = str.
			sub( /\A\n+/, '' ).
			sub( /\n+\z/, '' ).
			split( /\n{2,}/ )

		rval = grafs.collect {|graf|

			# Unhashify HTML blocks if this is a placeholder
			if rs.html_blocks.key?( graf )
				rs.html_blocks[ graf ]

			# Otherwise, wrap in <p> tags
			else
				apply_span_transforms(graf, rs).
					sub( /^[ ]*/, '<p>' ).gsub(/\r\n|\n/, '') + '</p>'
			end
		}.join("\n\n")

		@log.debug " Formed paragraphs: %p" % rval
		return rval
	end
	
	

	# 日本語修正: ひとつの段落内の各行を、完全に（改行文字を入れずに）結合する
	def transform_list_items( str, rs )
		@log.debug " Transforming list items"

		# Trim trailing blank lines
		str = str.sub( /\n{2,}\z/, "\n" )

		str.gsub( ListItemRegexp ) {|line|
			@log.debug "  Found item line %p" % line
			leading_line, item = $1, $4

			if leading_line or /\n{2,}/.match( item )
				@log.debug "   Found leading line or item has a blank"
				
				item = apply_block_transforms( outdent(item), rs )
			else
				# Recursion for sub-lists
				@log.debug "   Recursing for sublist"
				item = transform_lists( outdent(item), rs ).chomp
				item = apply_span_transforms( item, rs )
			end
			item.gsub!(/\n\s*/, '')

			%{<li>%s</li>\n} % item
		}
	end





		
	# EmptyElementSuffixをHTML向けに変更
	# （空要素に/を付けられるのはXHTMLのみ）
	HTMLEmptyElementSuffix = '>'
	
	# 変更：定数名の置き換え
	def transform_hrules( str, rs )
		@log.debug " Transforming horizontal rules"
		str.gsub( /^( ?[\-\*_] ?){3,}$/, "\n<hr#{HTMLEmptyElementSuffix}\n" )
	end


	# 変更：定数名の置き換え
	def apply_span_transforms( str, rs )
		@log.debug "Applying span transforms to:\n  %p" % str

		str = transform_code_spans( str, rs )
		str = encode_html( str )
		str = transform_images( str, rs )
		str = transform_anchors( str, rs )
		str = transform_italic_and_bold( str, rs )

		# Hard breaks
		str.gsub!( / {2,}\n/, "<br#{HTMLEmptyElementSuffix}\n" )

		@log.debug "Done with span transforms:\n  %p" % str
		return str
	end


	# 修正：正規表現のバグ（BlueClothのソースを参照）
	JInlineImageRegexp = %r{
		(					# Whole match = $1
			!\[ (.*?) \]	# alt text = $2
		  \([ ]*
			<?(\S+?)>?		# source url = $3
		    [ ]*
			(?:				# 
			  (["'])		# quote char = $4
			  (.*?)			# title = $5
			  \4			# matching quote
			  [ ]*
			)?				# title is optional
		  \)
		)
	  }x #"


	# Reference-style images
	JReferenceImageRegexp = %r{
		(					# Whole match = $1
			!\[ (.*?) \]	# Alt text = $2
			[ ]?			# Optional space
			(?:\n[ ]*)?		# One optional newline + spaces
			\[ (.*?) \]		# id = $3
		)
	  }x
		



	# 変更：定数名の置き換え
	def transform_images( str, rs )
		@log.debug " Transforming images" % str

		# Handle reference-style labeled images: ![alt text][id]
		str.
			gsub( JReferenceImageRegexp ) {|match|
				whole, alt, linkid = $1, $2, $3.downcase
				@log.debug "Matched %p" % match
				res = nil
				alt.gsub!( /"/, '&quot;' )

				# for shortcut links like ![this][].
				linkid = alt.downcase if linkid.empty?

				if rs.urls.key?( linkid )
					url = escape_md( rs.urls[linkid] )
					@log.debug "Found url '%s' for linkid '%s' " % [ url, linkid ]

					# Build the tag
					result = %{<img src="%s" alt="%s"} % [ url, alt ]
					if rs.titles.key?( linkid )
						result += %{ title="%s"} % escape_md( rs.titles[linkid] )
					end
					result += HTMLEmptyElementSuffix

				else
					result = whole
				end

				@log.debug "Replacing %p with %p" % [ match, result ]
				result
			}.

			# Inline image style
			gsub( JInlineImageRegexp ) {|match|
				@log.debug "Found inline image %p" % match
				whole, alt, title = $1, $2, $5
				url = escape_md( $3 )
				alt.gsub!( /"/, '&quot;' )

				# Build the tag
				result = %{<img src="%s" alt="%s"} % [ url, alt ]
				unless title.nil?
					title.gsub!( /"/, '&quot;' )
					result += %{ title="%s"} % escape_md( title )
				end
				result += HTMLEmptyElementSuffix

				@log.debug "Replacing %p with %p" % [ match, result ]
				result
			}
	end
	
	




end

