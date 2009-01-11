CAPTION = "HTMLで直接書く"


class Translator
	def text_to_html(text)
		
		
		return text
	end
	
	def format_guide
		return <<HTML
<p>文字通り、HTMLで直接記事を書くことができます。<a href="http://scl.littlestar.jp/pinkyblog/exlink.php">特殊リンク</a>を除き、一切の変換を行いません。</p>

<p>外部のHTMLエディタを使って記事を書きたいときや、他のblogツールで書いた記事を、そのままPinky:blogに転載したいときなどに便利です。</p>

<h3>注意点</h3>
<ul>
	<li>見出しを使う場合、<code>h1</code>ではなく<code>h3</code>から始めてください（以降<code>h4, h5, h6</code>）。<code>h1</code>がサイト名に、<code>h2</code>が記事タイトルに、それぞれ使われているためです。</li>
</ul>
HTML
	end
end

