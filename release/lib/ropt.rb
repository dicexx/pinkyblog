module ROpt
  ROPT_VERSION = "0.1.0"
  InvalidParseRuleError = Class.new(StandardError)

  class ParseResult
    attr_reader :args
    attr_reader :options
    def initialize(args, options)
      @args, @options = args, options
    end

    def [](key)
      case key
      when Fixnum; @args[key]
      when Symbol; @options.fetch(key.to_s)
      when String; @options.fetch(key)
      else; raise(TypeError, "Not suitable for key: #{key}")
      end
    end
  end #/ParseResult

  class ArgumentParser
    def initialize(*parse_rule_args, &missing_proc)
      @boolopts = {}
      @valopts = {}
      @multival_opts_set = {}
      @missing_proc = missing_proc || proc { false; }

      single_options = parse_rule_args.shift || ""
      single_options.scan(%r".:{0,2}") do |optspec|
        if optspec.size == 1
          @boolopts[optspec] = nil
        else
          opt = optspec[0, 1]
          @valopts[opt] = case optspec.size
                          when 2; nil
                          when 3
                            @multival_opts_set[opt] = true
                            nil
                          else; raise(InvalidParseRuleError,
                                      single_options)
                          end
        end
      end if single_options

      options = parse_rule_args
      options.each do |arg|
        unless arg =~ %r"\A([^:]+)(:{0,2})"
          raise(InvalidParseRuleError, arg)
        end
        opt = $~[1]
        corons = $~[2].size
        default_val = $~.post_match
        if corons == 0
          @boolopts[opt] = nil
        else
          @valopts[opt] = case $2.size
                          when 1; default_val.empty?() ? nil : default_val
                          when 2
                            @multival_opts_set[opt] = true
                            nil
                          else; raise(InvalidParseRuleError, arg)
                          end
        end
      end
    end

    # Based on getopts.rb
    def parse(argv)
      argv = argv.dup
      boolopts = @boolopts.dup
      valopts = @valopts.dup
      @multival_opts_set.each_key { |opt|
        valopts[opt] = []
      }
      c = 0
      while arg = argv.shift
        case arg
        when /\A--(.*)/
          if $1.empty?			# xinit -- -bpp 24
            break
          end

          opt, val = $1.split('=', 2)

          if opt.size == 1
            argv.unshift arg
            return nil
          elsif valopts.key? opt		# imclean --src +trash
            optval = (val || argv.shift) or return(nil)
            set_valopt(valopts, opt, optval)
          elsif boolopts.key? opt		# ruby --verbose
            boolopts[opt] = true
          else
            argv.unshift(val) if val
            @missing_proc[opt, argv] or return(nil)
          end

          c += 1
        when /\A-(.+)/
          opts = $1

          until opts.empty?
            opt = opts.slice!(0, 1)

            if valopts.key? opt
              val = opts

              if val.empty?			# ruby -e 'p $:'
                optval = argv.shift or return(nil)
                set_valopt(valopts, opt, optval)
              else				# cc -ohello ...
                set_valopt(valopts, opt, val)
              end

              c += 1
              break
            elsif boolopts.key? opt
              boolopts[opt] = true		# ruby -h
              c += 1
            else
              opts.empty? or argv.unshift(opts)
              @missing_proc[opt, argv] or return(nil)
              opts = opts.equal?(argv[0]) ? argv.shift.dup : ""
            end
          end
        else
          argv.unshift arg
          break
        end
      end

      opthash = boolopts
      opthash.update(valopts)
      ParseResult.new(argv, opthash)
    end #/getopts!

    def set_valopt(valopts, opt, val)
      if @multival_opts_set[opt]
        valopts[opt] << val
      else
        valopts[opt] = val
      end
    end
  end #/ArgumentParser

  class << self
    def parse(argv, *parse_rule_args, &missing_proc)
      ROpt::ArgumentParser.new(*parse_rule_args, &missing_proc).parse(argv)
    end
  end #/<< self
end #/ROpt
