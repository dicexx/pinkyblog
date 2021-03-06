#-----------------------------------------------------------
# 重要な設定
#-----------------------------------------------------------

# 管理パスワード
@master_password = 'test'



#-----------------------------------------------------------
# オプション（必要に応じて変更してください）
#-----------------------------------------------------------

# パス指定にPATH_INFOを使うかどうか
# （トップページ以外のページに正しくアクセスできない場合、true→falseに書き換えてみてください）
@use_path_info = true

# 記事データなどを格納するディレクトリのパス
@data_dir_path = './data/'

# システム本体＆ライブラリを格納するディレクトリのパス
# （Windows実行ファイル版では、このパス設定は影響しません）
@lib_dir_path = './lib/'

# モジュールを置くディレクトリのパス
@mod_dir_path = './mod/'

# CSS着せ替えテンプレートを置くディレクトリのパス
# （HTTPでアクセス可能な場所に置いてください）
@cdp_dir_path = './csstemplate/'

# 画像などを置くためのディレクトリのパス
# （HTTPでアクセス可能な位置を指定してください）
@res_dir_path = './res/'



#---------------------------------------------------------------
# サーバー動作オプション
#（Windows実行ファイル版、もしくはblog_server.rbを起動したときのみ使われます
#  必要に応じて変更してください）
#---------------------------------------------------------------

# サーバーのポート番号（標準:8888）
@http_server_port = 8888

# 静的URLリスト
# このリストにある文字列から始まるURLへのアクセスは、「静的ファイルの取得」として扱われます
# （例: /csstemplate がリストにあれば、 http://localhost:8888/csstemplate/style.css は静的ファイルとして取得可能）
@http_server_static_urls = %w(
	/csstemplate
	/res
)