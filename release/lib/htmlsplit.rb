
require 'cgi'

=begin Start of Document
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<title>htmlsplit.rb</title>
<link href="rubydoc.css" rel="stylesheet">
</head>
<body>
| <a href="./">戻る</a> |
<h1>HTML Split Library</h1>
<p> HTMLを読み書きする。 読み込んだ文書はタグと文字列の配列になる。 to_sメソッドでHTMLに戻すことが出来る。</p>
<h2>クラス一覧</h2>
<table bgcolor="#FFFFFF" border="1">
  <tr><td><a href="#HTMLSplit">HTMLSplit</a><td>HTMLをタグと文字データに分割する。 
<tr>
	<td><a href="#CharacterData">CharacterData</a>
	<td>文字データ
  <tr><td><a href="#EmptyElementTag">EmptyElementTag</a>
	<td>空要素のタグ
  <tr>
	<td><a href="#StartTag">StartTag</a>
	<td>開始タグ
  <tr>
	<td><a href="#EndTag">EndTag</a>
	<td>終了タグ
  <tr>
	<td><a href="#Comment">Comment</a>
	<td>コメント
  <tr>
	<td><a href="#Declaration">Declaration</a>
	<td>宣言(DOCTYPE)
  <tr>
	<td><a href="#SSI">SSI</a>
	<td>SSI※
  <tr>
	<td><a href="#ERuby">ERuby</a>
	<td>eRuby/ASP/JSPスクリプト※
  <tr>
	<td><a href="#PHP">PHP</a>
	<td>PHPスクリプト※
  </table>
※タグの属性値などに埋め込まれたスクリプトは認識できません。
<h2>使い方 </h2>
<h3>読み込み</h3>
<pre class="Exception"><samp>#!/usr/bin/ruby
require "htmlsplit"

obj = HTMlSplit.new(ARGF.read)</samp></pre>
<h3>出力</h3>
<pre>
obj.document.each {|e|
    print e.to_s
}
</pre>
<h3>属性の設定</h3>
<pre>
img = Tag('img/')
img['src']='xxx.png'  #&lt;img src="xxx.png"&gt;

o = Tag('option')
o['selected']=true    #&lt;option selected&gt;
</pre>
=end

class HTML_ElementTag
  def initialize name, attr = nil
		@name = name.downcase
		@attr = attr
	end
  attr_reader :name, :attr
  
	def to_s
		if @attr
			"<"+@name+@attr.keys.sort.collect{|n|
				v = @attr[n]
				if v==true
					' ' + n
				else
					' ' + n + '="' + CGI::escapeHTML(v) + '"'
				end
      }.join + ">"
		else
			"<#{@name}>"
		end
	end
  
	def [](key)
    @attr && @attr[key]
	end

	def []=(key,value)
    if value.nil?
      @attr && @attr.delete(key)
		else
      @attr = {} if !@attr
      @attr[key] = value
		end
	end
end

=begin EmptyElementTag
 
<h2><a name="EmptyElementTag">EmptyElementTag</a></h2>
空要素のタグ 
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">name</var>[,<var class="Hash">attr</var>])
  <dd>新しいオブジェクトを生成する。 <var class="String">name</var>はタグの名前 <var class="Hash">attr</var>はタグの属性nilまたはHash
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">name
  <dd>タグ名を返す。
  <dt class="Hash">attr 
  <dd>属性を返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
  <dt class="String">self[<var class="String">key</var>]
  <dd>keyに関連づけられた属性値を返します。
      該当するキーが登録されていない時には，nilを返します。
  <dt class="String">self[<var class="String">key</var>]= <var class="String">value</var>
  <dd><var class="String">key</var>に対して<var class="String">value</var>を関連づけます。
      <var class="String">value</var>がnilの時，<var class="String">key</var>に対する関連を取り除きます。
</dl>
=end
class EmptyElementTag < HTML_ElementTag
end


=begin StartTag
<h2>StartTag</h2>
開始タグ
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">name</var>[,<var class="Hash">attr</var>])
  <dd>新しいオブジェクトを生成する。 <var class="String">name</var>はタグの名前 <var class="Hash">attr</var>はタグの属性nilまたはHash
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">name
  <dd>タグ名を返す。
  <dt class="Hash">attr 
  <dd>属性を返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
  <dt class="String">self[<var class="String">key</var>]
  <dd>keyに関連づけられた属性値を返します。
      該当するキーが登録されていない時には，nilを返します。
  <dt class="String">self[<var class="String">key</var>]= <var class="String">value</var>
  <dd><var class="String">key</var>に対して<var class="String">value</var>を関連づけます。
      <var class="String">value</var>がnilの時，<var class="String">key</var>に対する関連を取り除きます。
</dl>
=end
class StartTag < HTML_ElementTag
end


=begin EndTag
<h2>EndTag</h2>
終了タグ
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">name</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">name</var>はタグの名前
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">name 
  <dd>タグ名を返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class EndTag
	def initialize(name)
		@name = name.downcase
	end
	attr_accessor :name
	def to_s
		"</#{@name}>"
	end
end



class HTML_NodeBase
  def initialize text
    @text = text
  end
  attr_accessor :text
end

=begin CharacterData
<h2>CharacterData</h2>
文字データ
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class CharacterData < HTML_NodeBase
	def to_s
		@text
	end
end


=begin Declaraion
<h2>Declaraion</h2>
SGML宣言
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class Declaration < HTML_NodeBase
	def to_s
		"<!#{@text}>"
	end
end


=begin Comment
<h2>Comment</h2>
コメント
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class Comment < HTML_NodeBase
	def to_s
		"<!--#{@text}-->"
	end
end


=begin SSI
<h2>SSI</h2>
SSI
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class SSI < HTML_NodeBase
	def to_s
		"<!--#{@text}-->"
	end
end


=begin ERuby
<h2>ERuby</h2>
eRuby/ASP/JSPスクリプト
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class ERuby < HTML_NodeBase
	def to_s
		"<%#{@text}%>"
	end
end


=begin PHP
<h2>PHP</h2>
PHPスクリプト
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">text</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">text</var>はテキスト
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="String">text 
  <dd>テキストを返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
</dl>
=end
class PHP < HTML_NodeBase
	def to_s
		"<?#{@text}?>"
	end
end


=begin HTMLSplit
 
<h2><a name="HTMLSplit">HTMLSplit</a></h2>
HTML読み書き 
<h3>クラスメソッド</h3>
<dl compact>
  <dt>new(<var class="String">html</var>)
  <dd>新しいオブジェクトを生成する。 <var class="String">html</var>はHTML文書
</dl>
<h3>メソッド</h3>
<dl compact>
  <dt class="Array">document 
  <dd>ドキュメントの配列を返す。
  <dt class="String">to_s 
  <dd>HTMLを返す。
  <dt class="Iterator">each {|<var>obj</var>,<var class="Array">tag</var>| ...}
  <dd>ドキュメントの各オブジェクト(<var>obj</var>)に対してブロックを評価します。
      <var class="Array">tag</var>は開始タグのリスト（ [ StartTag , <var class="Integer">インデクス</var>] ）
  <dt class="Integer">index(<var class="Class">class</var>, <var class="Integer">start</var>, <var class="Integer">end</var>, <var>value</var>, <var class="Integer">count</var>) {|obj| ...}
  <dd><var class="Integer">start</var>から<var class="Integer">end</var>までの要素で<var class="Class">class</var>と等しい<var class="Integer">count</var>番目の要素の位置を返します。
      等しい要素がひとつもなかった時にはnilを返します。<br>
      <var>value</var>にnil以外の値を指定した時には要素が<var>value</var>と等しいかチェックを行います。<var class="Class">class</var>がEmptyElementTag,StartTag,EndTagの時はタグ名、それ以外はテキストによって比較します。<br>
      ブロックを指定して呼び出された時にはブロックで要素が等しいか評価する。
  <dt class="Integer">end_index(<var class="Integer">start</var>)
  <dd><var class="Integer">start</var>に対応するEndTagのインデクスを返します。
      対応する要素がなかった時にはnilを返します。<br>
</dl>
=end
class HTMLSplit
	EMPTY = %w(area base basefont bgsound br col frame hr img input isindex 
	           keygen link meta nextid param spacer wbr)
  
  # コード（整数）→文字
  # unescapeHTML()から呼び出される
  def HTMLSplit.make_char encoding, code, unmatch
    if code == 0x9 || code == 0xa || code == 0xd || code >= 0x20 && code <= 0xff
      code.chr
    else
      if (code <= 0xd7ff ||
           code >= 0xe000 && code <= 0x10ffff && code != 0xfffe && code != 0xffff) && 
           encoding == "UTF8"
        [code].pack("U")
      else
         unmatch
      end
    end
  end

  def HTMLSplit.unescapeHTML string, encoding
    string.gsub(/&(.*?);/n) {
      match = $1.dup
      case match
      when /\Aamp\z/ni           then '&'
      when /\Aquot\z/ni          then '"'
      when /\Aapos\z/ni          then "'"
      when /\Agt\z/ni            then '>'
      when /\Alt\z/ni            then '<'
      when /\A#0*(\d+)\z/n
        HTMLSplit.make_char(encoding, Integer($1), "&##{$1};")
      when /\A#x([0-9a-f]+)\z/ni
        HTMLSplit.make_char(encoding, $1.hex, "&#x#{$1};")
      else
        "&#{match};"
      end
    }
  end

  def make_tag name, attr
    name.downcase!
    if @empty_tags.include?(name)
      @document << EmptyElementTag.new(name, attr)
    else
      if name[0, 1] == '/'
        @document << EndTag.new(name[1..-1])
      else
        @document << StartTag.new(name, attr)
      end
    end
  end
  private :make_tag

  def initialize html = nil, encoding = $KCODE
    @empty_tags = EMPTY
    set_html(html, encoding) if html
  end
  attr_reader :document
  attr_accessor :empty_tags
  
  # HTML文書をパースする。
  def set_html(html, encoding = $KCODE)
    @document = []	#パースしたHTMLのリスト
		name = ''
		text = ''
		attr = {}
		attrname = ''
		state = :TEXT
		#
		html.each_byte {|c|
			char = c.chr
			case state
			when :TEXT
				if c==60
					if text.length>0
						@document << CharacterData.new(text)
					end
					name = ''
					attr={}
					state = :TAGNAME
				else
					text << char
				end
			when :TAGNAME
        if name.length == 0
				case char
				when '!'
					text = ''
					state = :DECLARE
				when '%'
					text = ''
					state = :ERUBY
				when '?'
					text = ''
					state = :PHP
          when /[a-zA-Z_:\/]/
					name << char
          else
            text = '<' + char
            state = :TEXT
				end
        else
				case char
				when '>'
            make_tag(name, nil)
            text = ''
            state = :TEXT
          when /\s/
            text=''
            state = :SPACE
          when /[a-zA-Z0-9\._:-]/
            name << char
						else
            text = ''
            state = :SPACE
            redo
						end
					end
			when :SPACE	#属性間の空白
				case char
				when '>'
          make_tag(name, attr)
					text = ''
					state = :TEXT
        when '<'  # 閉じない開始タグ
          make_tag(name, attr)
          name = ''
          attr = {}
          state = :TAGNAME
				when /\s/
				else
					attrname=char
					state = :ATTRNAME
				end
			when :ATTRNAME	#属性名
				case char
				when /\s/
					state = :BEFOREEQUAL
				when '='
					state = :AFTEREQUAL
				when '>'
					attr[attrname.downcase]=true
          make_tag(name, attr)
					text = ''
					state = :TEXT
				else
					attrname << char
				end
			when :BEFOREEQUAL	#=
				case char
				when '='
					state = :AFTEREQUAL
				when '>'
					attr[attrname.downcase]=true
          make_tag(name, attr)
					text = ''
					state = :TEXT
				when /\s/
				else
					attr[attrname.downcase]=true
					attrname = char
					state = :ATTRNAME
				end
			when :AFTEREQUAL	#=
				case char
				when "'"
					text=''
					state = :SQVALUE
				when '"'
					text=''
					state = :DQVALUE
				when '>'
					attr[attrname.downcase]=true
          make_tag(name, attr)
					text = ''
					state = :TEXT
				when /\s/
				else
					text=char
					state = :VALUE
				end
      when :VALUE		#値
				case char
				when /\s/
          attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
					state = :SPACE
				when '>'
          attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
          make_tag(name, attr)
					text = ''
					state = :TEXT
				else
					text << char
				end
			when :SQVALUE	#'値'
				if c==39
          attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
					state = :SPACE
				else
					text << char
				end
			when :DQVALUE	#"値"
				if c==34
          attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
					state = :SPACE
				else
					text << char
				end
			when :COMMENT
				case char
				when '>'
					if text[-2,2]=='--'	#コメント終了	
						text = text[0..-3]
						if text=~/^#[a-z]+/	#SSI
							@document << SSI.new(text)
						else
							@document << Comment.new(text)
						end
						text = ''
						state = :TEXT
					else
						text << char
					end
				else
					text << char
				end
			when :ERUBY
				case char
				when '>'
					if text[-1,1]=='%'	#eRuby終了	
						text = text[0..-2]
						@document << ERuby.new(text)
						text = ''
						state = :TEXT
					else
						text << char
					end
				else
					text << char
				end
			when :PHP
				case char
				when '>'
					if text[-1,1]=='?'	#eRuby終了	
						text = text[0..-2]
						@document << PHP.new(text)
						text = ''
						state = :TEXT
					else
						text << char
					end
				else
					text << char
				end
			when :DECLARE
				case char
				when '>'
					@document << Declaration.new(text)
					text = ''
					state = :TEXT
				else
					text << char
					if text=='--'
						text = ''
						state = :COMMENT
					end
				end
			end
		}
		#EOFの処理
		case state
		when :TEXT
			@document << CharacterData.new(text) if text.length>0
		when :TAGNAME
			@document << CharacterData.new('<'+text)
    when :SPACE	#属性間の空白
      make_tag(name, attr)
    when :ATTRNAME	#属性名
			attr[attrname.downcase]=true
      make_tag(name, attr)
		when :BEFOREEQUAL	#=
			attr[attrname.downcase]=true
      make_tag(name, attr)
		when :AFTEREQUAL	#=
			attr[attrname.downcase]=true
      make_tag(name, attr)
    when :VALUE		#値
      attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
      make_tag(name, attr)
    when :SQVALUE	#'値'
      attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
    when :DQVALUE	#"値"
      attr[attrname.downcase]=HTMLSplit.unescapeHTML(text, encoding)
		when :COMMENT
			if text=~/^#[a-zA-Z]+/	#SSI
				@document << SSI.new(text)
			else
				@document << Comment.new(text)
			end
		when :ERUBY
			@document << ERuby.new(text)
		when :PHP
			@document << PHP.new(text)
		when :DECLARE
			@document << Declaration.new(text)
		end
	end
	#
	def to_s
		s = ''
		@document.each {|e|
			s<<(e.to_s)
		}
		s
	end
	#
	def each
		tag = []
		i = 0
		@document.each {|e|
			case e
			when StartTag
				tag.push [e,i]
			when EndTag
				idx = nil
				(tag.size-1).downto(0) {|j|
					if tag[j][0].name==e.name
						idx = j
						break
					end
				}
				#
				if idx
					if idx==0
						tag = []
					else
						tag = tag[0..idx-1]
					end
				end
			else
			end
			yield e,tag
			i += 1
		}
	end
	#
	def index(_class,_start=0,_end=-1,value=nil,count=1)
		idx=_start
		found=false
		@document[_start.._end].each {|obj|
			if obj.type==_class
				if value
					case obj
					when StartTag,EmptyElementTag,EndTag
						if value===obj.name
							if (not iterator?) or yield(obj)
								if (count-=1)<=0
									found = true
									break
								end
							end
						end
					else
						if value===obj.text
							if (not iterator?) or yield(obj)
								if (count-=1)<=0
									found = true
									break
								end
							end
						end
					end
				else
					if (not iterator?) or yield(obj)
						if (count-=1)<=0
							found = true
							break
						end
					end
				end
			end
			idx+=1
		}
		if found
			idx
		else
			nil
		end
	end
	#
	def end_index(start_index)
		tag = []
		end_index = nil
		(start_index...@document.size).each {|idx|
			e= @document[idx]
			case e
			when StartTag
				tag.push [e,idx]
			when EndTag
				i = nil
				(tag.size-1).downto(0) {|j|
					if tag[j][0].name==e.name
						i = j
						break
					end
				}
				#
				if i
					if i==0
						tag = []
					else
						tag = tag[0..i-1]
					end
				end
				if tag.size==0
					end_index = idx
					break
				end
			else
			end
		}
		end_index
	end
end
=begin End of Document
</body>
</html>
=end
