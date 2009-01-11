#-----------------------------------------------------------
# plain-text トランスレータ for Pinky:blog
#
# Author:   Dice
# License:  NYSL 0.9982 (http://www.kmonos.net/nysl/)
# URL:      http://scl.littlestar.jp/
#-----------------------------------------------------------

CAPTION = "テキストで書く（装飾しない）"

class Translator

	def text_to_html(text)
		return "<p>" + CGI.escapeHTML(text).split(/\r\n|\n/).join("<br>\n") + "</p>"
	end
	
	def format_guide
		<<TEXT
「テキストで書く」を選ぶと、このように入力した文章がそのまま表示されます。
装飾やリスト表示、他のページへのリンクを貼る事などは一切できませんが
記法を覚える必要がないため、手軽に日記を書きたい方にはオススメです。
TEXT
	end
end
