require 'pathname'
self_path = Pathname.new(__FILE__)
$LOAD_PATH << (self_path.parent.parent + 'lib')

require 'pinkyblog'
include PinkyBlog

describe PinkyBlog::Config do
	it '正しいデフォルト値を持つ' do
		config = PinkyBlog::Config.new
		
		config.auto_login.should be_true
	end
end


describe BasicEntry do
	before do
		@entry = BasicEntry.new
	end

	it '!がついたものは特殊タグ、そうでないものは通常タグ' do
		@entry.tags = %w(!特殊タグA ！特殊タグB 普通のタグ)
		@entry.tags.should == %w(!特殊タグA ！特殊タグB 普通のタグ)
		@entry.normal_tags.should == %w(普通のタグ)
		@entry.special_tags.should == %w(!特殊タグA ！特殊タグB)
		@entry.special_tag_names.should == %w(特殊タグA 特殊タグB)
	end

	it '通常はコメントできるが、「！コメント不可」のタグがついている場合はコメントできない' do
		@entry.should be_commentable
		@entry.tags = ['！コメント不可']
		@entry.should_not be_commentable
		@entry.tags = ['!コメント不可']
		@entry.should_not be_commentable
	end
	

end

describe StaticEntry do
	before do
		@entry = StaticEntry.new('sample-entry')
	end
	
	it "常にコメント不可" do
		@entry.should_not be_commentable
	end
	
	it "タグは空" do
		@entry.tags.should be_empty
		@entry.normal_tags.should be_empty
		@entry.special_tags.should be_empty
	end
end

share_as :Base do
	it '正しい相対URLを計算できる' do
		@req.route_to('/entries/2007').should == URI.parse(@route_to_dest)
	end
	
	it '自身の絶対URIを正確に再構築できる' do
		if @uri then
			@req.uri.should == URI.parse(@uri)
		end
	end
	
	it 'クエリパラメータを取得できる' do
		if @query then
			@query.each_pair do |k, v| 
				@req.get(k).should == v
			end
		end
	end
end


describe Request do
	describe '（普通のURI）' do
		include Base
		before do
			@req = Request.new('http://scl.littlestar.jp/pinky/')
			
			@route_to_dest = 'entries/2007'
		end
		
	end
	
	describe '（階層が深く複雑なURI）' do
		include Base
		before do
			@req = Request.new('http://scl.littlestar.jp/pinky/blog.cgi', '/recent/1000', 'a=20&b=30&action=test')
			
			@uri = 'http://scl.littlestar.jp/pinky/blog.cgi/recent/1000?a=20&b=30&action=test'
			@route_to_dest = '../entries/2007'
			@query = {'a' => '20', 'b' => '30', 'action' => 'test'}
		end
	end
	
	describe '（クッキーを含むとき）' do
		before do
			@req = Request.new('http://scl.littlestar.jp/pinky/blog.cgi', nil, nil, :cookies => {'ck' => ['foo']})
		end
		
		it '#get_cookieが値を文字列で返す' do
			@req.get_cookie('ck').should == 'foo'
		end
	end
	
	describe do
		before do
			@req = Request.new('http://scl.littlestar.jp/pinky/blog.cgi', '/entries')
		end
		
		it do
			@req.route_to('/').should == URI.parse('/pinky/blog.cgi')
		end
	end
	
	describe do
		it do
			req = Request.new('http://localhost/pinky/')
			req.file_route_to('res/file.png').should == URI.parse('res/file.png')
		end

	
		it do
			req = Request.new('http://localhost/pinky/blog.cgi')
			req.file_route_to('res/file.png').should == URI.parse('res/file.png')
		end
		
		it do
			req = Request.new('http://localhost/pinky/blog.cgi', '/')
			req.file_route_to('res/file.png').should == URI.parse('../res/file.png')
		end

		it do
			req = Request.new('http://localhost/pinky/blog.cgi', '/entries')
			req.file_route_to('res/file.png').should == URI.parse('../res/file.png')
		end

	end
end

describe ViewContext do
	before do
		@conf = PinkyBlog::Config.new
		@mod = ModuleHandler.new(@conf)
		@req = Request.new('http://localhost:8080/')
	end

	it '#snapshot_mode? は @snapshot_pathが存在するときtrue' do
		context = ViewContext.new(@conf, @mod, @req)
		(context.snapshot_mode?).should be_false
		context = ViewContext.new(@conf, @mod, @req, nil, './spec')
		(context.snapshot_mode?).should be_true
	end
	
end

describe Repository do
	before do
		@rep = RepositoryStub.new('./spec/test_data')
	end
	
	it do
		Proc.new{@rep.check_transaction}.should raise_error
		Proc.new{@rep.lock{|r| r.check_transaction}}.should_not raise_error
	end
end



share_as :ScreenBasicExamples do
	it '#to_sがHTML文字列を返す' do
		@screen.to_s.should be_a_kind_of(String)
	end
	
	it 'Content-Typeは常にtext/html' do
		@screen.headers['Content-Type'].should == 'text/html'
	end
	
	it 'HTTPステータスが正しい' do
		@screen.http_status.should == @expected_status
	end
end

describe Screen do
	ENTRY_SAMPLE = Entry.new('sample')

	before do
		@conf = PinkyBlog::Config.new
		@context = ViewContext.new(@conf, ModuleHandler.new(@conf), Request.new('http://localhost/'))
		@expected_status = HTTP_OK
	end
	
	
	describe TopScreen do
		include ScreenBasicExamples
		before do
			@screen = TopScreen.new(@context, {:recent_entries => [], :welcome_entry => ENTRY_SAMPLE})
		end
	end
	
	describe AboutScreen do
		include ScreenBasicExamples
		before do
			@screen = AboutScreen.new(@context, {:about_blog_entry => ENTRY_SAMPLE, :about_writer_entry => ENTRY_SAMPLE})
		end
	end

	
	describe EntryListScreen do
		include ScreenBasicExamples
		before do
			@screen = EntryListScreen.new(@context, {:entries => []})
		end
	end


end


describe Application do

	DATA_PATH = Pathname.new('./spec/temp_data')
	
	before(:all) do
		@conf = PinkyBlog::Config.new
		@conf.instance_eval{@data_dir_path = DATA_PATH}
		
		Dir.mkdir(DATA_PATH) unless DATA_PATH.exist?
		Pathname.glob(DATA_PATH + '**/*.*'){|x| x.delete}
		
	end
	
	before(:each) do
		@app = ApplicationStub.new(@conf)
	end


	describe '（GETリクエストを受けたとき）' do
		SCRIPT_URI = 'http://homes/blog.cgi'
	
		it '解析不可URIへのGETに対しては、400でエラー表示' do
			req = Request.new(SCRIPT_URI, '/unknown_path')
			scr = @app.request(req)
			scr.should be_a_kind_of(ErrorScreen)
			scr.http_status.should == HTTP_BAD_REQUEST
		end
		
		it 'ログイン状態でない場合には、管理メニューやその下位ページにはアクセスできない' do
			list = ['/master_menu',  '/master_menu/blog_config']
			list.each do |path|
				req = Request.new(SCRIPT_URI, path)
				scr = @app.request(req)
				scr.should be_a_kind_of(ForbiddenScreen)
				scr.http_status.should == HTTP_FORBIDDEN
			end
		end
	
	
	
		it 'GET / => トップページ' do
			req = Request.new(SCRIPT_URI)
			@app.request(req).should be_a_kind_of(TopScreen)
			req = Request.new(SCRIPT_URI, '/')
			@app.request(req).should be_a_kind_of(TopScreen)
		end
		
		table = [
			['entries', '記事一覧', EntryListScreen],
			['search', '検索フォーム', SearchScreen],
			['about', 'blogについて', AboutScreen],
			['recent', '最近の記事', RecentScreen],
			['news_feed', 'ニュースフィード', NewsFeedScreen],
			['login', 'ログイン', LoginFormScreen],
			['entries', '記事一覧', EntryListScreen],
		]
	
		table.each do |path, desc, screen_class|
			it "GET #{path} => #{desc}" do
				req = Request.new(SCRIPT_URI, path)
				@app.request(req).should be_a_kind_of(screen_class)
			end
		end
		
		it "GET entries/123 => 記事" do
			@app.repository.lock{|x| x.save_entry(StaticEntry.new('123'))}
			req = Request.new(SCRIPT_URI, 'entries/123')
			@app.request(req).should be_a_kind_of(EntryScreen)
		end

	
	
	
	end



	describe '（POSTリクエストを受けたとき）' do
		
		def request(query)
			@app.request(Request.new('http://homes/blog.cgi', '/post', query))
		end
		
		it do
			scr = request('action=master_login&password=test')
			scr.http_status.should == HTTP_SEE_OTHER
			scr.path.should == 'master_menu'
			scr = request('action=master_login&password=invalid')
			scr.http_status.should == HTTP_BAD_REQUEST
		end
	end
end