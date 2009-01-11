#-> OptionCheck

module PinkyBlog
	# オプション引数を取り扱うためのモジュール
	# このモジュールがextendされたクラス内では
	# require_optで必要とするオプションパラメータを追加できる
	module OptionCheck
		def require_opt(*names)
			@required_option_names ||= []
			@required_option_names += names
		end
		
		def default_opt(name, value)
			@default_options ||= {}
			@default_options[name] = value
		end
		
		
		def fulfill_requirement?(option_args)
			if @required_option_names then
				return false unless @required_option_names.all?{|name| option_args.include?(name)}
			end
			
			return true
		end
		
		

		
		def set_defaults(option_args)
			(@default_options || {}).each_pair do |name, value|
				option_args[name] = value unless option_args.has_key?(name)
			end
			
			return self
		end
		
		def assert_fulfill_requirement(option_args)
			unless fulfill_requirement?(option_args) then
				lacks = @required_option_names - option_args.keys
				str = lacks.map{|x| "'#{x.to_s}'"}.join(', ')
				raise ArgumentError, ("option-args are not enough : #{self.to_s} requires #{str}")
			end
		end

		def inherited(sub)
			if @required_option_names then
				sub.instance_variable_set('@required_option_names', @required_option_names)
			end
			
			if @default_options then
				sub.instance_variable_set('@default_options', @default_options) 
			end
			
		end

		
	end
end
