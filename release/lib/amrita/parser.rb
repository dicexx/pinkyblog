
# Amrita -- A html/xml template library for Ruby.
# Copyright (c) 2002 Taku Nakajima.
# Licensed under the Ruby's License.

# Copyright (c) 2003-2005, maintenanced by HORIKAWA Hisashi.
#     http://www.nslabs.jp/amrita-altered.rhtml

# -*- encoding:utf-8 -*-

require 'strscan'
require "amrita/node"
require "amrita/tag"

module Amrita

  class HtmlScanner  #:nodoc:all
    include Amrita

    def HtmlScanner.scan_text(text, &block)
      scanner = new(text)
      pos = -1
      loop do
	state, value = *(scanner.scan { text[pos+=1] })
	#puts ":#{state}:#{value.type}" 

	break unless state

	yield(state, value)
      end
    end

    def initialize(src, taginfo=DefaultHtmlTagInfo)
      @sc = StringScanner.new(src)
      @taginfo = taginfo
      @src_str = src
      @text = ""
      @tagname = ""
      @attrs = []
      @attrname = ""
      @attrvalue = ""
      @push_back_value = []
      @state = method(:state_text)
    end

    def scan
      if @push_back_value.size > 0
	return @push_back_value.pop 
      end
      loop do
	return nil if  @sc.empty?
	@pointer = @sc.pointer
	#next_text = @sc.peek(10)
	#puts "#{next_text}:#{state}:#{value}:#{@state}"
	state, value = *@state.call
	#puts "#{state}:#{value}:#{@state}"

	return [state, value] if state
      end
    end

    def push_back(state, value)
      @push_back_value.push([state, value])
    end

    def empty?
      @push_back_value.size == 0 and @sc.empty?
    end

    def generate_tag
      @tagname.downcase!
      klass = @taginfo.get_tag_info(@tagname).tag_class || Tag
      ret = klass.new(@tagname, @attrs)
      @tagname = ""
      @attrs = []
      [:tag, ret]
    end

    NAME_RE = /([A-Za-z:_][\w.:-]*)/

    def state_text
      t = @sc.scan(/\A[^<]*/m)
      if t
	@state = method(:state_tagname)
	t.gsub!("&gt;", ">")
	t.gsub!("&lt;", "<")
	t.gsub!("&amp;", "&")
	t.gsub!("&quot;", '"') #"
	#t.gsub!("&nbsp;", " ")
        t.gsub!(/&#(\d+);/) { $1.to_i.chr } 
	if t.size > 0
	  [:text, t]
	else
	  nil
	end
      else
	[:text, @sc.scan(/\A.*/m)]
      end
    end

    def state_tagname
      l = @sc.skip(/\A</)
      raise "can't happen" unless l == 1
      
      @sc.skip(/\A\s+/m)
      if t = @sc.scan(/\A\/?#{NAME_RE}/)
	@state = method(:state_space)
	@tagname = t
	nil
      elsif t = @sc.scan(/\A!--|%=|%|\?|!/)
	@state = method(:state_special_tag)
	@tagname = t
	nil
      elsif t = @sc.scan(/\A[^>]+/m)
	@sc.skip(/\A>/)
	@tagname = t
	@state = method(:state_text)
	generate_tag
      else
	raise "can't happen"
      end
    end

    # <と>の間のスペース
    def state_space
      @sc.skip(/\A\s*/m)
      if @sc.scan(/\A>|\/>/)
	@state = method(:state_text)
	generate_tag
      elsif t = @sc.scan(/\A#{NAME_RE}/m)
	@attrname = t
	@state = method(:state_attrname)
	nil
      else
        raise "can't happen at #{@sc.pos}"	
      end
    end

    def state_attrname
      @sc.skip(/\A\s*/m)
      if t = @sc.scan(/\A#{NAME_RE}/m)
	@attrname = t
	@state = method(:state_before_equal)
	nil
      elsif t = @sc.scan(/\A=/)
	@state = method(:state_after_equal)
	nil
      elsif t = @sc.scan(/\A>|\/>/)
	@attrs << [@attrname, nil]
	@state = method(:state_text)
	generate_tag
      else
	raise "can't happen"	
      end
    end

    def state_before_equal
      @sc.skip(/\A\s*/m)
      if t = @sc.scan(/\A=/)
	@state = method(:state_after_equal)
	nil
      elsif t = @sc.scan(/\A>|\/>/) 
	@attrs << [@attrname, nil]
	@state = method(:state_text)
	generate_tag
      elsif t = @sc.scan(/\A#{NAME_RE}/)
	@attrs << [@attrname, nil]
	@attrvalue = ""
	@attrname = t
	@state = method(:state_attrname)
	nil
      else
	raise "can't happen"	
      end
    end

    def state_after_equal
      @sc.skip(/\A\s*/m)
      if t = @sc.scan(/\A"/) #"
	@state = method(:state_dqvalue)
	nil
      elsif t = @sc.scan(/\A'/) #'
	@state = method(:state_sqvalue)
	nil
      elsif t = @sc.scan(/\A>|\/>/)
	@attrs << [@attrname, nil]
	@state = method(:state_text)
	generate_tag
      elsif t = @sc.scan(/\A[^\s>]+/m)
	@attrs << [@attrname, t]
	@state = method(:state_space)
	nil
      elsif t = @sc.scan(/\A[^>]*/m)
	@attrs << [@attrname, t]
	@state = method(:state_attrname)
	nil
      else
	raise "can't happen"	
      end
    end
    
    def state_sqvalue
      t = @sc.scan(/\A[^']*/m) #'
      if t
        @attrs << [@attrname, t]
	@state = method(:state_space)
	@sc.skip(/\A'/) #'
	nil
      else
	raise "can't happen"	
      end
    end

    def state_dqvalue
      t = @sc.scan(/\A[^"]*/m) #"
      if t
        @attrs << [@attrname, t]
	@state = method(:state_space)
	@sc.skip(/\A"/) #"
	nil
      else
	raise "can't happen"	
      end
    end

    def state_special_tag
      re = end_tag_size = nil
      case @tagname
      when '%=', '%'
        re = /\A[^>]*%>/m
        end_tag_size = -2
      when '!--'
        re = /\A.*?-->/m 
        end_tag_size = -3
      when '?'
        re = /\A([^>]*)\?>/m
        end_tag_size = -2
	when '!'
        re = /\A([^>]*)>/m
        end_tag_size = -1
      else
        raise "can't happen"	
      end
      t = @sc.scan_until(re)
      raise "can't happen" unless t
      text = t[0...end_tag_size]
      @state = method(:state_text)
      [:special_tag, [@tagname, text]]
    end

    def current_line
      @sc.string[@pointer, 80]    
    end

    def current_line_no
      #done = @sc.string[0, @pointer]    
      done = @src_str[0, @pointer]    
      done.count("\n")
    end
  end

  class HtmlParseError < StandardError
    attr_reader :error, :fname, :lno, :line

    def initialize(error, fname, lno, line)
      @error, @fname, @lno, @line = error, fname, lno, line
      super("error hapend in #{@fname}:#{@lno}(#{error}) \n==>#{line}")
    end
  end

  class Multi   #:nodoc: all
    attr_reader :alt

    def initialize(alt)
      @child_nodes = []
      @alt = alt
      @cur = 0
    end
    
    def <<(node)
      raise TypeError if !node.is_a?(TemplateNode)

      @child_nodes << node
      return self
    end
    
    def size()
      return @child_nodes.size
    end

    def inspect()
      "[alt=#{@alt}, " + @child_nodes.collect {|n| n.inspect()}.join(", ") + "]"
    end
  end

  class TemplateNode  #:nodoc: all
    attr_reader(
      :child_nodes,
      :ref_node)        # Nodeオブジェクトへの参照の配列
    attr_accessor(
      :parent)          # 親ノード
    protected :parent=

    def initialize()
      @child_nodes = {}
    end

    def insert_child(name, t_node, alt)
      raise TypeError if !t_node.is_a?(TemplateNode)
      raise TypeError if !name.is_a?(String)
      t_node.parent = self
      
      if alt || @child_nodes[name]
        if @child_nodes[name].is_a?(Multi)
          @child_nodes[name] << t_node
        else
          m = Multi.new(alt)
          m << @child_nodes[name] if @child_nodes[name]
          m << t_node
          @child_nodes[name] = m
        end
        t_node.ref_node.multi = @child_nodes[name]
      else
        @child_nodes[name] = t_node
      end
    end

    def set_ref(dnode)
      raise TypeError if !(dnode.is_a?(Element) || dnode.is_a?(Attr))
      @ref_node = dnode
      return self
    end

    def inspect()
      "<#{ref_str(@ref_node)}>, {" + 
      @child_nodes.collect {|k, v| "#{k} => " + v.inspect()}.join(", ") + "}"
    end

    private
    def ref_str(node)
      return "" if node.nil?
      raise TypeError, "expected a Node but #{node.class}" if !node.is_a?(Node)
      r = ""
      while true
        case node
        when Element
          sibling = node.parent.child_nodes.select {|v|
                                     v.is_a?(Element) && v.name == node.name}
          if sibling.size <= 1
            r = "/" + node.name + r
          else
            sibling.each_with_index {|s, i|
              if node.equal?(s)
                r = "/#{node.name}[#{i}]#{r}"
                break
              end
            }
          end
          node = node.parent
        when Attr
          r = "/@" + node.name + r
          node = node.element
        else
          break
        end
      end
      return r
    end
  end

  # HTMLパーサ兼テンプレート木を生成する
  class HtmlParser
    def HtmlParser.parse_inline(text, taginfo = DefaultHtmlTagInfo)
      c = caller(1)[0].split(":")
      parser = HtmlParser.new(text, c[0], c[1].to_i, taginfo)
      parser.parse
    end

    def HtmlParser.parse_text(text, fname = nil, lno = 0, taginfo = DefaultHtmlTagInfo)
      parser = HtmlParser.new(text, fname, lno, taginfo)
      parser.parse
    end
    
    def HtmlParser.parse_io(io, fname = nil, lno = 0, taginfo = DefaultHtmlTagInfo)
      parser = HtmlParser.new(io.read(), fname, lno, taginfo)
      parser.parse
    end
    
    def HtmlParser.parse_file(fname, taginfo = DefaultHtmlTagInfo)
      File.open(fname) {|f|
        HtmlParser.parse_io(f, fname, 0, taginfo)
      }
    end

    attr_accessor(
      :tmpl_id,     # テンプレートエンジンで使う属性名
      :attr_style)  # 属性展開を要素の子とするか、並列とするか

    def initialize(source, fname, lno, taginfo)
      @scanner = HtmlScanner.new(source, taginfo)
      @taginfo = taginfo
      @tmpl_id = "amrita_id"
      @attr_style = "1.8"  # 属性は要素の子
    end

    def parse()
      root_doc = Element.new("<root>".intern)
      root_tmpl = TemplateNode.new()
      parse1(root_doc, root_tmpl)
      return root_doc.body
    end
    
    private
    def append_new_ref(parent_tnode, name, dnode)
      raise TypeError, "must be a Node, but #{dnode.class}" if !(dnode.is_a?(Element) || dnode.is_a?(Attr))
      raise TypeError if !name.is_a?(String)

      if name[-1] == ?+
        if dnode.attrs[@tmpl_id].value != name
          raise "template was invalid"
        else
          alt = true
          name = name[0..-2]
          dnode.attrs[@tmpl_id] = name
        end
      end

      t = TemplateNode.new()
      t.set_ref(dnode)
      parent_tnode.insert_child(name, t, alt)
      return t
    end
    
    def generate_element(tag)
      a = tag.attrs.collect {|k, v| Attr.new(k, v)}
      Element.new(tag.name.intern, *a)
    end

    def parse1(cur_doc_node, cur_tmpl_node)
      while true
        state, value = @scanner.scan()
        case state
        when :tag
          # valueはTagオブジェクト
          if value.start_tag?  # 開始タグ or 空要素タグ
            if @taginfo.accept_child?(cur_doc_node, value.name)
              child = generate_element(value)
              cur_doc_node.add child

              if child.attrs[@tmpl_id]
                # <foo tmplid="tmpl_name">
                t = append_new_ref(cur_tmpl_node, child.attrs[@tmpl_id].value, child)
                
                # <foo tmplid="tmpl_name1" bar="@tmpl_name2">
                child.attrs.each {|a|
                  if a.value && a.value[0] == ?@
                    if @attr_style < "1.8"
                      append_new_ref(cur_tmpl_node, a.value[1..-1], a)  # amrita.orig 1.0互換
                    else
                      append_new_ref(t, a.value[1..-1], a)
                    end
                  end
                }
              else
                # <foo bar="@tmpl_name">
                child.attrs.each {|a|
                  if a.value && a.value[0] == ?@
                    append_new_ref(cur_tmpl_node, a.value[1..-1], a)
                  end
                }
                t = cur_tmpl_node
              end
              parse1(child, t) if !value.empty_tag?
            else
              @scanner.push_back(state, value)
              return
            end
          else
            if cur_doc_node.tagname == value.name[1..-1]
              return
            else
              @scanner.push_back(state, value)
              return
            end
          end
        when :text
          cur_doc_node.add TextElement.new(value)
        when :special_tag
          cur_doc_node.add SpecialElement.new(value[0], value[1])
        when nil
          break
        else
          raise "unknown scanner_token #{state}"
        end
      end
    end
  end
  
end

