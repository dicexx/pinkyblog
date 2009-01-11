# encoding: utf-8
$KCODE = 'u'

require 'pathname'
require 'stringio'
require 'rubygems'
require 'hpricot'

self_path = Pathname.new(__FILE__)
$LOAD_PATH << (self_path.parent.parent + 'release/lib')

require 'pinkyblog'
include PinkyBlog
require 'rack/mock'

describe PinkyBlog::Config do
	it '正しいデフォルト値を持つ' do
		config = PinkyBlog::Config.new
		
		config.auto_login.should be_true
	end
end

describe Util do
	it '通常のvalidateを正確に行え、なおかつuntaintが済んでいる' do
		str = 'spec'.taint
		Util.validate(str, 4).should be_true
		str.should_not be_tainted
		
		str = 'specs'.taint
		Util.validate(str, 4).should be_false
		str.should be_tainted
	end
	
	['abcd1234', 'abcd', '1234567890abcdef'].each do |ok_pass|
		it "パスワード '#{ok_pass}' のvalidateが成功する" do
			Util.validate_password(ok_pass).should be_true
		end
	end
	
	
	['aBC', '1234567890abcdefg', '', '123 56', '12345+', 'マルチバイト'].each do |ng_pass|
		it "パスワード '#{ng_pass}' のvalidateが失敗する" do
			Util.validate_password(ng_pass).should be_false
		end
	end
	
	data = [
		['http://scl.littlestar.jp/', 20, 'http://scl.littl ...'],
		['http://scl.littlestar.jp/', 40, 'http://scl.littlestar.jp/'],
	]
	data.each do |str, max_length, expect|
		it "clip (#{str} (#{max_length} byte) => #{expect})" do
			Util.clip(str, max_length).should == expect
		end
	end
end

describe Menu do
	data = []
	data << ['top', %w(), MenuItem::Top, true, true]
	data << ['top', %w(-m), MenuItem::Top, false, true]
	data << ['top', %w(--guest-only), MenuItem::Top, true, false]
	data << ['top', %w(--guest-only), MenuItem::Top, true, false]
	data << ['uri', %w(http://example.net/), MenuItem::URI, true, true]
	data << ['url', %w(http://example.net/), MenuItem::URI, true, true]
	
	data.each do |cmd_name, args, cls, g_visible, m_visible|
		cmd = "#{cmd_name} #{args.join(' ')}"
		it "メニュー定義 '#{cmd}' を正しく解釈できる" do
			item = MenuItem.create('', cmd_name, args)
			item.should be_kind_of(cls)
			item.visible_by_guest?.should == g_visible
			item.visible_by_master?.should == m_visible
		end
	end

	data = []
	data << ['uri', %w(-a href), MenuItem::URI, true, true]
	
	data.each do |cmd_name, args, cls, g_visible, m_visible|
		cmd = "#{cmd_name} #{args.join(' ')}"
		it "メニュー定義 '#{cmd}' を解釈したときに ArgumentParseError を発生させる" do
			proc{
				MenuItem.create('', cmd_name, args)
			}.should raise_error(MenuItem::ArgumentParseError)
		end
	end


end


describe PinkyBlog::Config do
	it '期待されるデフォルト値を持つ' do
		config = PinkyBlog::Config.new
		
		config.menu_type.should == MT::SIMPLE
		config.page_changing_type.should == PCT::INDEX # 変更不可
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



describe Repository do
	before do
		path = Pathname('./spec/test_data')
		@rep = Repository.new(path, false)
		Dir.mkdir(@rep.dir_path) unless @rep.dir_path.exist?
		@rep.check_valid
	end
	
	after do
		@rep.entry_dir_path.children.each{|x| x.delete}
	end
	
	it "非ロック時にcheck_transactionが実行されたら、エラーを発生する" do
		Proc.new{@rep.check_transaction}.should raise_error
	end
	
	it "ロック時にcheck_transactionが実行されたら、何のエラーも発生させない" do
		Proc.new{@rep.lock{|r| r.check_transaction}}.should_not raise_error
	end
	
	it 'parity.json に記録されたハッシュと、digest_fileで直接計算したハッシュが等しい' do
		entry = BasicEntry.new
		id = entry.id
		@rep.lock{
			@rep.save_entry(entry).should be_true
		}
		
		digest = Util.digest_file(@rep.get_entry_file_path(id))
		loaded = @rep.load_parity['entry'][id]
		
		digest.should == loaded
	end
end


describe Request do
	before do
		@env = Rack::MockRequest::DEFAULT_ENV
	end
	
	it 'should parse tags' do
		tags = %w(first second 三番目)
		req = Request.new(@env.merge('QUERY_STRING' => "tags_1=#{Util.encode_base64url(tags[0])}&tags_2=#{Util.encode_base64url(tags[1])}&tags_3=#{Util.encode_base64url(tags[2])}"))
		req.tags.should == tags
	end
end

describe Application::Log::MTCompatible do
	data = [
		['10/11/2008 12:05:30', Time.local(2008, 10, 11, 12, 5, 30)],
		[' 10/11/2008 12:05:30 ', Time.local(2008, 10, 11, 12, 5, 30)],
		['10/11/2008 00:05:30 PM', Time.local(2008, 10, 11, 12, 5, 30)],
		['05/04/2008 04:10:05 AM', Time.local(2008, 5, 4, 4, 10, 5)],
		['05/04/2008 04:10:05 AM', Time.local(2008, 5, 4, 4, 10, 5)],
	]
	
	data.each do |str, expected|
		it "MT形式の日時文字列をパース (\"#{str}\" => #{expected.to_s})" do
			logmod = Application::Log::MTCompatible
			logmod.parse_date(str).should == expected
			logmod.parse_date(logmod.format_to_date(logmod.parse_date(str))).should == expected
		end
	end

#	it 'interchange date' do
#		Time.now.should == Application::Log::MTCompatible.parse_date(Application::Log::MTCompatible.format_to_date(Time.now))
#	end
end

describe 'Paging' do
	before(:each) do
		@config = PinkyBlog::Config.new
		@config.lib_dir_path = 'release/lib'
	end

	data = [[0, 'page 1'], [1, 'page 1'], [6, 'page 1 - page 2'], [7, 'page 1 - page 2 - page 3']]
	data.each do |entry_number, expected_text|
		it "#{entry_number}個の記事があるとき、標準設定でのページ表示は '#{expected_text}' になる" do
			conf = @config
			req = Request.new(Rack::MockRequest.env_for)
			context = ViewContext.new(conf, req)
			opts = {:entries => [BasicEntry.new] * entry_number, :attached_image_table => {}, :module_handler => ModuleHandler.new(conf)}
			
			scr = RecentScreen.new(context, opts)
			elements = Hpricot(scr.to_s) / ".pinky-page-index"
			elements.first.inner_text.should == expected_text
		end
	end
	
	data = [[12, 0, 'page 1'], [12, 3, 'page 2'], [12, 6, 'page 3']]
	data.each do |entry_number, start, expected|
	
		it "#{entry_number}個の記事があって1ページあたり3記事、始点が#{start}のとき、現在のページは '#{expected}' になる" do
			conf = @config
			req = Request.new(Rack::MockRequest.env_for)
			context = ViewContext.new(conf, req)
			opts = {:start => start, :entries => [BasicEntry.new] * entry_number, :attached_image_table => {}, :module_handler => ModuleHandler.new(conf)}
			
			scr = RecentScreen.new(context, opts)
			elements = Hpricot(scr.to_s) / ".pinky-page-index em"
			elements.first.inner_text.should == expected
		end
	end
end






class BlogCaller
	def initialize
		conf = PinkyBlog::Config.new
		@pinky_blog_app = PinkyBlog::Application.load(conf)
	end

	def call(env)
		req = PinkyBlog::Request.new(env)
		screen = @pinky_blog_app.request(req)
		resp = screen.to_rack_response
		
		return resp.to_a
	end
end




describe PinkyBlog do
	before(:all) do
		Dir.chdir('release')
		@mock_req = Rack::MockRequest.new(BlogCaller.new)
	end

	list = %w(/ /entries /recent /login /entries/welcome /search)

	list.each do |uri|
		it "#{uri} へのリクエストが成功する" do
			res = @mock_req.get(uri)
			res.status.should == 200
		end
	end
end