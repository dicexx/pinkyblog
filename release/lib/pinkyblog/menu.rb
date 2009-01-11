require 'amrita/template'
require 'shellwords'
require 'ropt'

require 'pinkyblog/util'
require 'pinkyblog/view-context'

module PinkyBlog
	class Menu
		attr_reader :items
	
		def initialize(items = [])
			@items = items
		end
		
		def get_current_item(context)
			
			if context.path_refered_by_menu then
				current_path = Util.normalize_path(context.path_refered_by_menu)
			else
				current_path = context.request.normalized_path
			end

			if current_path == '/' then
				return @items.first
			else
				# パスとクエリが一致→パスのみが一致、の順で検索
				found = @items.find{|x| x.path == current_path and x.query == context.request.GET}
				if found then
					return found
				else
					return @items.find{|x| x.path == current_path}
				end
			end
		end
		
		def to_model(context)

			re = []
			@items.each_with_index do |item, i|
				next if not context.master_mode? and not item.visible_by_guest?
				next if context.master_mode? and not item.visible_by_master?
				next if context.snapshot_mode? and not item.visible_on_snapshot?

				re << item.to_model(context, i)
				if item == get_current_item(context) then
					re.last[:class] = 'menu-on'
				end
				
				# トップページの場合の処理
				if i == 0 then
					re.last[:a]['href'] = context.route_to('/')
				end
			end
			
			re
		end
		
		
		def self.parse(text)
			items = []
		
			text = text.gsub("\r\n", "\n")
			text.each_with_index do |line, number|
				if line =~ /^(.+?)\s*\|\s*(.+)\s*$/ then
					caption, cmd = $1, $2
					cmd_args = Shellwords.shellwords(cmd)
					cmd_name = cmd_args.shift
					item = MenuItem.create(caption, cmd_name, cmd_args, number + 1)
					
					items << item if item
				end
			end
			
			unless items.find{|x| x.kind_of?(MenuItem::MasterMenu)} then
				raise MenuError, 'メニュー項目の中には、かならず「管理者メニュー」（mastermenu）を含んでいる必要があります。'
			end
			
			return self.new(items)
		end
	end
	
	class MenuError < StandardError
	end

	module MenuItem
		GUEST_ONLY = :guest_only
		MASTER_ONLY = :master_only
	
		class ArgumentParseError < StandardError
			attr_accessor :text_line_number, :menu_caption
		end
	
		def self.create(caption, cmd_name, cmd_args, line_number = nil)
			case cmd_name
			when 'top'
				return Top.new(caption, cmd_args, line_number)
			when 'about'
				return About.new(caption, cmd_args, line_number)
			when 'entry'
				return Entry.new(caption, cmd_args, line_number)
			when 'entries'
				return Entries.new(caption, cmd_args, line_number)
			when 'recent'
				return Recent.new(caption, cmd_args, line_number)
			when 'list'
				return EntryList.new(caption, cmd_args, line_number)
			when 'search'
				return Search.new(caption, cmd_args, line_number)
			when 'newsfeed'
				return NewsFeed.new(caption, cmd_args, line_number)
			when 'login'
				return Login.new(caption, cmd_args, line_number)
			when 'logout'
				return Logout.new(caption, cmd_args, line_number)
			when 'master', 'mastermenu'
				return MasterMenu.new(caption, cmd_args, line_number)
			when 'addentry', 'write'
				return AddEntry.new(caption, cmd_args, line_number)
			when 'url', 'uri'
				return URI.new(caption, cmd_args, line_number)
			else
				return nil
			end
		end
	
	
		class Base
			attr_reader :caption, :visibility
			def initialize(caption, args = [], line_number = nil)
				@caption = caption
				@visibility = nil
				
				re = ROpt.parse(args, short_option_spec, *long_option_spec)
				if re then
					on_option_parsed(re)
				else
					error = ArgumentParseError.new((line_number ? "illegal menu definition, on line #{line_number}" : ""))
					error.text_line_number = line_number
					error.menu_caption = caption
					raise error
				end
			end
			
			def path
			end
			
			def query
				{}
			end
			
			def visible_by_guest?
				visibility != MASTER_ONLY
			end
			
			def visible_by_master?
				visibility != GUEST_ONLY
			end
			
			def visible_on_snapshot?
				false
			end
			
			def short_option_spec
				'mg'
			end
			
			def long_option_spec
				['master-only', 'guest-only']
			end
			
			def on_option_parsed(re)
				if re['master-only'] || re['m'] then
					@visibility = MASTER_ONLY
				elsif re['guest-only'] || re['g'] then
					@visibility = GUEST_ONLY
				end
			end
			
			
			
			
			def to_model(context, index)
				model = {}
				
				model[:a] = Amrita.a({:href => build_href(context)}){@caption}
				model[:id] = sprintf("MENU%02d", index + 1)
				return model
			end
			
			def to_pan
				[path, @caption]
			end
			
			private
			def build_href(context)
				query_string = query.to_a.map{|k, v| "#{k}=#{v}"}.join('&')
				context.route_to(path, (query_string.empty? ? nil : query_string))
			end
			
			
		end
		
		module TagOption
			def short_option_spec
				super << 't::x::'
			end
			
			def long_option_spec
				super << 'tag::' << 'exclude-tag::'
			end
			
			def on_option_parsed(re)
				super
				@tags = re['tag'] + re['t']
				@excluded_tags = re['exclude-tag'] + re['x']
			end
			
			def query
				re = super
				@tags.each_with_index do |tag, i|
					re["tags_#{i}"] = Util.encode_base64url(tag)
				end

				@excluded_tags.each_with_index do |tag, i|
					re["extags_#{i}"] = Util.encode_base64url(tag)
				end

				
				re
			end

		end
		
		class Top < Base
			def path
				'/top'
			end
			
			def visible_on_snapshot?
				true
			end
		end

		class About < Base
			def path
				'/about'
			end
			
			def visible_on_snapshot?
				true
			end
		end
		
		class Entry < Base
			def short_option_spec
				super << 's'
			end
			
			def long_option_spec
				super << 'simple'
			end
			
			def on_option_parsed(re)
				super
				@simple = re['simple'] || re['s']
				@entry_id = re.args.first
				raise ArgumentParseError unless @entry_id
			end
		
			def path
				"/entries/#{@entry_id}"
			end
			
			def query
				if @simple then
					super.merge({'simple' => '1'})
				else
					super
				end
			end
			
			def visible_on_snapshot?
				true
			end

		end
		
		class Entries < Base
			def on_option_parsed(re)
				super
				@entry_ids = re.args
			end
		
			def path
				"/entries/#{@entry_ids.join(';')}"
			end
			
			def visible_on_snapshot?
				true
			end

		end


		
		class Recent < Base
			include TagOption
			
			def short_option_spec
				super << 'n:'
			end
			
			def long_option_spec
				super << 'number:'
			end
			
			def on_option_parsed(re)
				super
				n = re['number'] || re['n']
				@number = (n ? n.to_i : nil)
			end
			
			def query
				re = super
				re['number'] = @number if @number
				re
			end

		
			def path
				'/recent'
			end
			
		end
		
		class EntryList < Base
			def path
				'/entries'
			end
			
			
			def short_option_spec
				super << 's:r'
			end
			
			def long_option_spec
				super << 'sort-by:' << 'reverse'
			end
			
			def on_option_parsed(re)
				super
				@sort = re['sort-by'] || re['s']
				@reverse = true if re['reverse'] or re['r']
			end
			
			def query
				re = super
				re['sort'] = @sort if @sort
				re['order'] = Order::REVERSE if @reverse
				
				re
			end

			def visible_on_snapshot?
				true
			end

		end



		class Search < Base
			def path
				'/search'
			end
		end

		class NewsFeed < Base
			def path
				'/news_feed'
			end
		end

		class AddEntry < Base
			def path
				'/master_menu/entry_add_form'
			end
			
			def visibility
				MASTER_ONLY
			end
			
			def short_option_spec
				super << 't::'
			end
			
			def long_option_spec
				super << 'tag::'
			end
			
			def on_option_parsed(re)
				super
				@tags = re['tag'] + re['t']
			end
			
			def query
				re = super
				@tags.each_with_index do |tag, i|
					re["tags_#{i}"] ||= []
					re["tags_#{i}"] << Util.encode_base64url(tag)
				end
				
				re
			end
		end

		
		class Login < Base
			def path
				'/login'
			end
			
			def visibility
				GUEST_ONLY
			end
		end

		class Logout < Base
			def path
				'/'
			end
			
			def query
				super.merge('logout' => '1')
			end
			
			def visibility
				MASTER_ONLY
			end
		end

		
		class MasterMenu < Base
			def path
				'/master_menu'
			end
			
			def visibility
				MASTER_ONLY
			end
		end

		class URI < Base
			def on_option_parsed(re)
				super
				@uri = re.args.first
				raise ArgumentParseError unless @uri
			end
			
			def build_href(context)
				@uri
			end
		end


	end
	
end
