# PinkyBlogコア
module PinkyBlog
	CORE_VERSION = '1.82 (candy)'
	CORE_VERSION_NUMBER = 1.82
	CORE_VERSION.concat " Windows実行ファイル版" if defined?(ExerbRuntime)

	require 'pinkyblog/application'
	require 'pinkyblog/request'
	require 'pinkyblog/screen'
end
