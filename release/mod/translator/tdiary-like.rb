#-----------------------------------------------------------
# tdiary-like トランスレータ for Pinky:blog
#
# Copyright (C) 2001-2005, TADA Tadashi <sho@spc.gr.jp>
# You can redistribute it and/or modify it under GPL2
#
# Arranger:  Dice
#-----------------------------------------------------------

CAPTION = "tDiary記法で書く"

class Translator
	def text_to_html(text)
		sections = text.split(/\n\n/).map{|x| Section.new(x)}
		
		
		return sections.map{|x| x.to_html}.join("\n")
	end
	
	def format_guide
		return <<TDIARY
tDiary記法とは
ただただし氏開発の日記ツール、<a href="http://www.tdiary.org/">tDiary</a> の標準スタイルとほぼ同じ形式の記法です。HTMLでの記述を基本としつつ、普通の文章を書くだけであれば、ほとんどHTMLタグを使わずに書けるようになっています。
詳しくは、<a href="http://docs.tdiary.org/ja/">tDiary ドキュメント Wiki</a>の、<a href="http://docs.tdiary.org/ja/?tDiary%A5%B9%A5%BF%A5%A4%A5%EB">tDiary スタイルについて書かれたページ</a>を参考にしてください。

tDiaryとの違い
<ul>
  <li>セクションアンカーは付きません。</li>
  <li>セクションごとの見出し（サブタイトル）は、HTMLで言うと h2 ではなく h3 になります。</li>
  <li>tDiaryのプラグイン記法（ &lt;%= %&gt;）は使えません。</li>
	<li>Pinky:blog固有の<a href="http://scl.littlestar.jp/pinkyblog/exlink.php">特殊リンク</a>が使用できます。</li>
</ul>

簡易サンプル
<pre>セクション１
一行目が見出し（サブタイトル）、二行目以降が本文になります。
本文は一行ごとに一つの段落になります。つまり、改行すると次の段落になります。
 
セクション２
↑のように、空行がセクションの区切りになります。
 
セクション３
&lt;ul&gt;
  &lt;li&gt;セクションの中に &amp;lt; から始まる行があった場合、そのセクション全体が整形の対象にならなくなります。&lt;/li&gt;
  &lt;li&gt;このように、改行しても次の段落にならないのが分かります。&lt;/li&gt;
  &lt;li&gt;リストを記述したいときなどに便利です。&lt;/li&gt;
&lt;/ul&gt;
 
&lt;&lt;a href="#DUMMY"&gt;セクション４&lt;/a&gt;
見出しのはじめをHTMLタグから書き始めたい場合には、 &amp;lt; 記号を行頭に一つ余分に重ねてください。</pre>

 こう書くと、次のように表示されます。

<blockquote>

セクション１
一行目が見出し（サブタイトル）、二行目以降が本文になります。
本文は一行ごとに一つの段落になります。つまり、改行すると次の段落になります。

セクション２
↑のように、空行がセクションの区切りになります。

セクション３
<ul>
<li>セクションの中に &lt; から始まる行があった場合、そのセクション全体が整形の対象にならなくなります。</li>
<li>このように、改行しても次の段落にならないのが分かります。</li>
<li>リストを記述したいときなどに便利です。</li>
</ul>

<<a href="#DUMMY">セクション４</a>
見出しのはじめをHTMLタグから書き始めたい場合には、 &lt; 記号を行頭に一つ余分に重ねてください。

</blockquote>
TDIARY
	end
end


class Section
	def initialize(fragment)
	
		lines = fragment.split( /\n+/ )
		if lines.size > 1 then
			if /^<</ =~ lines.first then
				@subtitle = lines.shift.chomp.sub( /^</, '' )
			elsif /^[ 　<]/ !~ lines.first then
				@subtitle = lines.shift.chomp
			end
		end
		
		@paragraphs = lines
		
	end
	
	def body_to_html
		html = ""
		@paragraphs.each do |p|
			if p[0] == ?< then
				html = @paragraphs.join("\n")
				break
			else
				html << "<p>#{p}</p>\n"
			end
		end
		return html
	end
	
	def to_html
		html = ""
		html << "<h3>#{@subtitle}</h3>\n" if @subtitle
		html << body_to_html
		return html
	end
end
