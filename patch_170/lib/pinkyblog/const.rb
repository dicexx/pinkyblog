# PinkyBlog定数

module PinkyBlog

	
	prefix = '^[!！]'
	suffix = '$'
	SPECIAL_TAG_BASE_PATTERN = /#{prefix}(.+)#{suffix}/
	SPECIAL_TAG_NAME_PATTERNS = {}
	SPECIAL_TAG_NAME_PATTERNS[:uncommentable] = /#{prefix}コメント不可#{suffix}/
	SPECIAL_TAG_NAME_PATTERNS[:url_invisible] = /#{prefix}(?:URL|ＵＲＬ)非表示#{suffix}/
	
	STATIC_ENTRY_DEFAULT_TITLES = {}
	STATIC_ENTRY_DEFAULT_TITLES['welcome'] = ''
	#STATIC_ENTRY_TITLES['message_response'] = 'ひとことレス'
	STATIC_ENTRY_DEFAULT_TITLES['about_blog'] = "このblogについて"
	STATIC_ENTRY_DEFAULT_TITLES['about_writer'] = "執筆者について"
	
	LIMIT_TIGHT = 'tight'
	LIMIT_LOOSE = 'loose'
	LIMIT_VERY_LOOSE = 'very-loose'
	LIMIT_TABLE = {
		:message_length => {'tight' => 80, 'loose' => 160, 'very-loose' => 300},
		:comment_length => {'tight' => 150, 'loose' => 300, 'very-loose' => 800},
	}
	
	
	# CGI#outに渡すためのステータスコード
	# スペルミス防止のために定数として定義してある
	HTTP_OK = HTTP_200 = '200 OK'
	HTTP_PARTIAL_CONTENT = HTTP_206 = '206 Partial Content'
	HTTP_MULTIPLE_CHOICES = HTTP_300 = '300 Multiple Choices'
	HTTP_MOVED = HTTP_MOVED_PERMANENTLY = HTTP_301 = '301 Moved Permanently'
	HTTP_FOUND = HTTP_302 = '302 Found'
	HTTP_SEE_OTHER = HTTP_303 = '303 See Other'
	HTTP_NOT_MODIFIED = HTTP_304 = '304 Not Modified'
	HTTP_BAD_REQUEST = HTTP_400 = '400 Bad Request'
	HTTP_AUTH_REQUIRED = HTTP_AUTHORIZATION_REQUIRED =\
		HTTP_401 = '401 Authorization Required'
	HTTP_FORBIDDEN = HTTP_403 = '403 Forbidden'
	HTTP_NOT_FOUND = HTTP_404 = '404 Not Found'
	HTTP_METHOD_NOT_ALLOWED = HTTP_405 = '405 Method Not Allowed'
	HTTP_NOT_ACCEPTABLE = HTTP_406 = '406 Not Acceptable'
	HTTP_CONFLICT = HTTP_409 = '409 Conflict'
	HTTP_GONE = HTTP_410 = '410 Gone'
	HTTP_SERVER_ERROR = HTTP_INTERNAL_SERVER_ERROR =\
		HTTP_500 = '500 Internal Server Error'
	
	MASTER_SESSION_TIME_LIMIT = 60*60*24*14
	
	ENTRY_LIST_PAGE_LENGTH = 15
	RECENT_ENTRY_PAGE_LENGTH = 3
	
	EXTRA_ADDRESS_NUMBER = 4
	
	#COMMENT_LENGTH_MAX = 500
	#MESSAGE_LENGTH_MAX = 160
	
	NOTIFIED_MESSAGE_NUMBER = 100
	REFERER_MAX_LENGTH = 80
	
	
	# ソート方式
	module Sort
		BY_MODIFIED = 'modified'
		BY_CREATED = 'created'
		BY_ACCESS = 'access'
		BY_FILE_SIZE = 'file_size'
		BY_TITLE = 'title'
	end
	include Sort
	
	module Order
		REVERSE = 'reverse'
	end
	
	# 画像の表示形式
	module ImageDisplay
		INVISIBLE = 'invisible'
		SMALL_SIZE = 'small-size'
		ORIGINAL_SIZE = 'original-size'
		LINK = 'link'
		
		DEFAULT = SMALL_SIZE
	end
	ID = ImageDisplay
	
	module AutoDateDisplayType
		NO = 'no'
		CREATED = 'created'
		UPDATED = 'updated'
	end
	ADDT = AutoDateDisplayType
	
	module PageChangingType
		SEQUENTIAL = 'sequential'
		INDEX = 'index'
	end
	PCT = PageChangingType
	
	module MenuType
		SIMPLE = 'simple'
		DIRECT = 'direct'
	end
	MT = MenuType
	
	module LogFormat
		MT_COMPATIBLE_UTF8 = 'mt_utf-8'
		MT_COMPATIBLE_SJIS = 'mt_shift-jis'
		MT_COMPATIBLE_EUC = 'mt_euc-jp'
		PBLOG = 'pblog'
		PBLOG_GZIP = 'pblog_gzip'
	end
	LF = LogFormat
	
	
	DEFAULT_MENU_KEYS = %w(blog_top about recent_entries entry_list search news_feed master_menu)
	REQUIRED_MENU_KEYS = %w(blog_top master_menu) # 簡易メニュー編集のみで有効。メニュー定義ファイルを直接編集する場合には無視される
	SNAPSHOT_MENU_KEYS = %w(blog_top about entry_list)
	SNAPSHOT_REQUIRED_MENU_KEYS = %w(blog_top entry_list master_menu)
	
	DEFAULT_MENU_COMMAND_TABLE = {}
	DEFAULT_MENU_KEYS.each do |key|
		DEFAULT_MENU_COMMAND_TABLE[key] = key
	end
	DEFAULT_MENU_COMMAND_TABLE['blog_top'] = 'top'
	DEFAULT_MENU_COMMAND_TABLE['recent_entries'] = 'recent'
	DEFAULT_MENU_COMMAND_TABLE['news_feed'] = 'newsfeed'
	DEFAULT_MENU_COMMAND_TABLE['entry_list'] = 'list'
	DEFAULT_MENU_COMMAND_TABLE['master_menu'] = 'mastermenu'

	DEFAULT_MENU_TEXT = <<TEXT
blog top | top
about | about
recent entries | recent
entry list | list
search | search
news feed | newsfeed
master menu | mastermenu
TEXT

=begin
	items = []
	items << MenuItem::Top.new('blog top')
	items << MenuItem::About.new('about')
	items << MenuItem::Recent.new('recent entries')
	items << MenuItem::EntryList.new('entry list')
	items << MenuItem::Search.new('search')
	items << MenuItem::NewsFeed.new('news feed')
	items << MenuItem::MasterMenu.new('master menu')
	
	DEFAULT_MENU = Menu.new(items)
=end
end



