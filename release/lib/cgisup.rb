# Ruby CGI Adjuster Library
# Copyright (c) 2002-2005 HORIKAWA Hisashi. All rights reserved.
# You can redistribute this software and/or modify it under the Ruby's License.
#     mailto:vzw00011@nifty.ne.jp
#     http://www.nslabs.jp/

require "cgi/session"
require "digest/md5"
require "time"

class CGI
  module QueryExtension
  if $COMPAT_VERSION && $COMPAT_VERSION < '1.8.0'
    def [](key)
      return @params[key]
    end
  elsif RUBY_VERSION == '1.8.1' || RUBY_VERSION == '1.8.2'
    def [](key)
      value = @params[key].first
      if @multipart
        if value
          return value
        elsif defined?(StringIO)
          StringIO.new("")
        else
          Tempfile.new("CGI")
        end
      else
        return value || ""
      end
    end
  end

    def file_control(key)
      io, = @params[key]
      if !io
        return nil
      elsif !defined?(io.read)
        raise RuntimeError, "The enctype attribute must be 'multipart/form-data.'"
      else
        return io
      end
    end

    # @return control value or default value.
    def get(key, default = "")
      value = @params[key].first
          # コントロールkeyが存在しないときは、enctypeに関わらず valueはnilになる。
      if defined?(value.read)
        return value.read
      else
        return value || default
      end
    end
  end
end

class CGI
  class Session
    include Enumerable

    class FileStore
      if RUBY_VERSION >= '1.8.0' && RUBY_VERSION <= '1.8.1'
        def delete()     # override the original
          path = @f.path
          @f.close
          File.unlink path.untaint   # changed
        end
      end

      # セッション保存ファイルのうち，古いものを削除する
      # @param option オプションを格納したハッシュ。tmpdir，holdtime必須。
      def FileStore.sweep_sessions(option)
        dir = option['tmpdir']
        prefix = option['prefix'] || ''
        holdtime = option['holdtime']
        raise ArgumentError, "no tmpdir option" if !dir
        raise ArgumentError, "no holdtime option" if !holdtime

        now = Time.now
        Dir.glob(dir + "/" + prefix + "*") {|fname|
          fname.untaint
          File.open(fname, "r") {|fp|
            # ロックはしない
            fp.each_line {|line|
              k, v = line.chomp.split('=', 2)
              if k == CGI.unescape("_last-accessed")
                if CGI.unescape(v) != "" &&
                          Time.rfc2822(CGI.unescape(v)) + holdtime < now
                  File.unlink fp.path.untaint
                  break
                end
              end
            }
          }
        }
      end

      # @param option オプションを格納したハッシュ。tmpdir必須。
      # @return セッションファイルが存在したらtrue
      def FileStore.exist?(id, option)
        raise SecurityError, "session_id '#{id}' is invalid" if /[^0-9a-zA-Z]/ =~ id.to_s

        dir = option['tmpdir']
        raise ArgumentError, "no tmpdir option" if !dir || dir == ""

        # FileStore#initialize()に合わせること。
        if RUBY_RELEASE_DATE >= "2004-12-22"  # v1.8.1 -> 1.8.2
          path = dir + "/" + (option['prefix'] || '') +
                 Digest::MD5.hexdigest(id)[0, 16] + (option['suffix'] || '')
        elsif RUBY_RELEASE_DATE >= "2004-11-16"  # v1.8.1 -> 1.8.2
          path = dir + "/" + (option['prefix'] || 'cgi_sid_') +
                 Digest::MD5.hexdigest(id)[0, 16] + (option['suffix'] || '')
        else
          path = dir + "/" + (option['prefix'] || '') + id.dup.untaint
        end
        return FileTest.exist?(path)
      end
    end # of Session::FileStore

    if RUBY_RELEASE_DATE < "2004-12-15"
    class NoSession < RuntimeError; end
    attr_reader :new_session
    def create_new_id()
      @new_session = true
      return Session::create_new_id()
    end
    private :create_new_id
    end

    # override the original
    #    session_key  セッションキー。省略すると'_session_id'
    #    session_id   セッションIDを明示的に指定。セキュリティ的に脆弱になるので注意。
    #    new_session  bool値。セッションIDが得られないときに、新しいセッションを開始するか。
    def initialize(request, option = {})
      @new_session = false
      session_key = option['session_key'] || '_session_id'
      session_id = option['session_id']
      if !session_id && option['new_session']
        session_id = create_new_id()
      end
      if !session_id
        session_id = Session.get_id_in_request(request, option)
                                 # ここを修正した。
                                 # CGI#[]を変更したため、ここを修正する必要あり。
      end
      if !session_id
        if option.key?('new_session') and not option['new_session']
          raise ArgumentError, "session_key `%s' should be supplied" % session_key
        end
        session_id = create_new_id()
      end

      @session_id = session_id
      dbman = option['database_manager'] || FileStore
      begin
        @dbman = dbman::new(self, option)
      rescue NoSession
        if option.key?('new_session') and not option['new_session']
          raise ArgumentError, "invalid session_id `%s'" % session_id
        end
        session_id = @session_id = create_new_id()
        retry
      end

      request.instance_eval do
	@output_hidden = {session_key => session_id} unless option['no_hidden']
	@output_cookies =  [
          Cookie::new("name" => session_key,
		      "value" => session_id,
		      "expires" => option['session_expires'],
		      "domain" => option['session_domain'],
		      "secure" => option['session_secure'],
		      "path" => if option['session_path'] then
				  option['session_path']
		                elsif ENV["SCRIPT_NAME"] then
				  File::dirname(ENV["SCRIPT_NAME"])
				else
				  ""
				end)
        ] unless option['no_cookies']
      end
      @dbprot = [@dbman]
      ObjectSpace::define_finalizer(self, Session::callback(@dbprot))
    end

    def Session.get_id_in_request(request, option)
      session_key = option['session_key'] || '_session_id'
      if request.key?(session_key)
        id = request.get(session_key)
      end
      id, = request.cookies[session_key] if !id
      if id
        dbman = option['database_manager'] || FileStore
        if dbman.exist?(id, option)
          return id
        end
      end
      return nil
    end
    
    def Session.exist?(request, option)
      return get_id_in_request(request, option) ? true : false
    end

    # セッションが存在すればSessionインスタンスを、そうでなければnilを返す
    def Session.get(request, option)
      if id = get_id_in_request(request, option)
        return Session.new(request, option.dup.update({"session_id" => id}))
      else
        return nil
      end
    end

    def Session.sweep(option)
      dbman = option['database_manager'] || FileStore
      dbman.sweep_sessions(option)
    end

    def update_access_time()
      self["_last-accessed"] = CGI.rfc1123_date(Time.now)
    end

    def each()
      if !@data
        @data = @dbman.restore
      end
      @data.each {|k, v|
        if k != "_last-accessed"
          yield k, v
        end
      }
    end
  end
end

# メニューコントロールを生成する
# @param name select要素の名前
# @param options 選択肢のvalueの配列（eachメソッドを持つオブジェクト）
# @param default 初期状態で選択されるvalue
# @param block 選択肢の表示文字列
def menu_control(name, options, default = nil)
  s = "<select name=\"#{name}\">\n"
  options.each {|x|
    selected = default == x ? " selected" : ""
    if block_given?
      s << "  <option#{selected} value=\"#{x}\">#{yield(x)}\n"
    else
      s << "  <option#{selected} value=\"#{x}\">#{x}\n"
    end
  }
  s << "</select>"
  return s
end
