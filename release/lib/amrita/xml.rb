
# Amrita -- A html/xml template library for Ruby.
# Copyright (c) 2002 Taku Nakajima.
# Licensed under the Ruby's License.

# Copyright (c) 2003-2005, maintenanced by HORIKAWA Hisashi.
#     http://www.nslabs.jp/amrita-altered.rhtml

# -*- encoding:utf-8 -*-

require "amrita/node"
require "rexml/document"
require "rexml/streamlistener"

module Amrita
  has_uconv = true
  begin
    require 'uconv'
  rescue LoadError
    has_uconv = false
  end
  if has_uconv 
    case $KCODE
    when "EUC"
      def convert(s)
        Uconv::u8toeuc(s)
      end
    when "SJIS"
      def convert(s)
        Uconv::u8tosjis(s)
      end
    else
      def convert(s)
        s
      end
    end
  else
    def convert(s)
      s
    end
  end

  class Listener
    include Amrita
    include REXML::StreamListener


    def initialize
      @stack = [ Null ]
    end

    def push(element)      
      @stack.unshift element
    end

    def pop
      @stack.shift
    end

    def top
     @stack.first
    end

    def result
      raise "can't happen @stack.size=#{@stack.size}" unless @stack.size == 1
      top
    end
    
    # override
    def tag_start(name, attrs)
      a = attrs.collect do |key, val|
        Attr.new(key, convert(val))
      end
      push e(name.intern, *a)
      push Null
    end

    # override
    def tag_end(name)
      body = pop
      element = pop
      element.init_body { body }
      push(pop + element)
    end

    # override
    def text(text)
      push(pop + TextElement.new(convert(text)))
    end
    
    # override
    def instruction(name, instruction)
      push(pop + SpecialElement.new('?', name + instruction))
    end
    
    # override
    def comment(comment)
      push(pop + SpecialElement.new('!--', comment))
    end
    
    # override
    def cdata(content)
      push(pop + SpecialElement.new('![CDATA[', content))
    end

    # override
    def xmldecl(version, encoding, standalone)
      text = %Q[xml version="#{version}"]
      text += %Q[ encoding="#{encoding}"] if encoding
      s = SpecialElement.new('?', text)
      push(pop + s)
    end

    # override
    def doctype(name, pub_sys, long_name, uri)
      s = SpecialElement.new('!',
                             %Q[DOCTYPE #{name} #{pub_sys} #{long_name} #{uri}])
      push(pop + s)
    end
  end

  class XMLParser
    attr_accessor(
      :tmpl_id,
      :attr_style)
    
    def XMLParser.parse_text(text, fname="", lno=0, dummy=nil, &block)
      parser = XMLParser.new(text, fname, lno, dummy)
      return parser.parse()
    end

    def XMLParser.parse_file(fname, dummy=nil, &block)
      l = Listener.new(&block) 
      REXML::Document.parse_stream(File.open(fname), l)
      l.result
    end

    def initialize(source, fname, lno, dummy__)
      @listener = Listener.new
      @source = source
    end
    
    def parse()
      REXML::Document.parse_stream(@source, @listener)
      @listener.result
    end
  end
end
