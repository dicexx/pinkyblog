
# Amrita -- A html/xml template library for Ruby.
# Copyright (c) 2002 Taku Nakajima.
# Licensed under the Ruby's License.

# Copyright (c) 2003-2005, maintenanced by HORIKAWA Hisashi.
#     http://www.nslabs.jp/amrita-altered.rhtml

# -*- encoding:utf-8 -*-

class String #:nodoc:
  # to treat Symbol and String equally
  def id2name
    self
  end

  # clone and freeze a String to share it
  def frozen_copy
    if frozen?
      self
    else
      dup.freeze
    end
  end
end

class Symbol #:nodoc:
  # to treat Symbol and String equally
  def intern
    self
  end
end

module Amrita 

  # represents a +key+ +value+ pair in HTML Element
  class Attr
    attr_reader :key, :value

    def initialize(key, value=nil)
      raise TypeError, "key must be a String" if !key.is_a?(String)
      @key = key
      case value
      when nil
        @value = nil
      when String
        @value = value.frozen_copy
      else
        @value = value.to_s.freeze 
      end
    end 

    def clone
      Attr.new(@key, @value)
    end

    def ==(x)
      return false unless x.kind_of?(Attr)
      x.key == @key and x.value == @value
    end

    def to_ruby
      if key =~ /^\w+$/
        if value
          "a(:#{key}, \"#{value}\")"
        else
          "a(:#{key})"
        end
      else
        if value
          "a(\"#{key}\", \"#{value}\")"
        else
          "a(\"#{key}\")"
        end
      end
    end
  end

  # Array of Attr s.
  # It can hold +body+ part for using as a model data for Node#expand.
  # Amrita#a() method is a shortcut for Attr.new
  class AttrArray
    include Enumerable

    # If you call a() { ... }, block yields to +body+
    # bodyは、elementの内容になる。
    attr_reader :body

    # Don't use AttrArray.new use a() instead
    def initialize(*attrs, &block)
      @array = []
      attrs.each do |a|
        case a
        when Array, AttrArray
          a.each do |aa|
            self << aa
          end
        when Hash
          attrs[0].each do |k, v|
            k = k.id2name if k.is_a?(Symbol)
            self << Attr.new(k, v)
          end
        else
          self << a
        end
      end

      if block_given?
        @body = yield 
      else
        @body = Null
      end
    end

    # AttrArray#== concerns the order of Attr
    def ==(x)
      return true if object_id == x.object_id
      return nil unless x.kind_of?(AttrArray)
      return false if size != x.size
      @array.each {|attr|
        return false if attr != x[attr.key]
      }
      true
    end

    def inspect
      to_ruby
    end

    # add an Attr
    def <<(a)
      case a
      when Attr
        @array.each_with_index {|x, idx|
          if x.key == a.key
            @array[idx] = a
            return self
          end
        }
        @array << a
      when AttrArray
        a.each {|attr|
          self << attr
        }
      else
        raise "must be Attr or AttrArray, not #{a.class}"
      end
      self
    end

    def clear
      @array.clear
      self
    end

    def [](index)
      raise TypeError, "must be a String, but #{index.class}" if !index.is_a?(String)
      @array.each {|x| return x if x.key == index}
      nil
    end

    def []=(index, val)
      raise TypeError, "must be a String, but #{index.class}" if !index.is_a?(String)

      if val.is_a?(Attr)
        raise if index != val.key
      else
        val = Attr.new(index, val)
      end
      self << val
      val
    end
    
    def delete(key)
      raise TypeError, "must be a String" if !key.is_a?(String)
      @array.each_with_index {|x, idx|
        if x.key == key
          return @array.delete_at(idx)
        end
      }
      nil
    end
    
    # iterate on each Attr
    def each(&block)
      @array.dup.each(&block)
    end

    def size
      @array.size
    end

    def to_ruby
      ret = "a(" + @array.collect {|v| ":#{v.key}, #{v.value}"}.join(", ") + ")"
      case @body
      when nil, Null
      when Node
        ret += body.to_ruby
      else
        ret += body.inspect
      end
      ret
    end
    
    def clone()
      AttrArray.new(self) {@body.clone}
    end
  end

  # Base module for HTML elements
  module Node
    include Enumerable

    # set the +block+ 's result to +body+
    def init_body(&block)
      if block_given?
        @body = to_node(yield)
      else
        @body = Null
      end
    end

    # a Node has NullNode as body before init_body was called.
    def body
      if defined? @body
        @body
      else
        Null
      end
    end

    # test if it has any children
    def no_child?
      body.kind_of?(NullNode)
    end

    # return an Array of child Node or an empty Array if it does not have a body
    def children
      if no_child?
        []
      else
        [ body ]
      end
    end

    # generate a Node object
    # 要素をcloneしない。
    def to_node(n)
      case n
      when nil, false
        Null
      when Node
        n
      when Array, NodeArray
        case n.size()
        when 0
          Null
        when 1
          to_node(n[0])
        else
          r = NodeArray.new
          n.each {|node| r << node}
          r
        end
      else
        TextElement.new(n.to_s) 
      end
    end
    module_function :to_node

    def inspect
      to_ruby
    end

    # Node can be added and they become NodeArray
    def +(node)
      NodeArray.new(self, to_node(node))
    end

    # Copy a Node n times and generate NodeArray
    def *(n)
      raise "can't #{self.class} * #{n}(#{n.class})" unless n.kind_of?(Integer)
      a = (0...n).collect { |i| self }
      NodeArray.new(*a)
    end

    # iterate on self and children
    def each_node(&block)
      c = children # save children before yield
      yield(self)
      c.each do |n|
        n.each_node(&block)
      end
    end

    # iterate on child Elements
    def each_element(&block)
      each_node do |node|
        yield(node) if node.kind_of?(Element)
      end
    end
    alias each each_element
  end

  # singleton and immutable object
  class NullNode #:nodoc:
    include Node

    private_class_method :new

    # NullNode::new can not be used. Use this instead.
    def NullNode.instance
      new
    end

    def ==(x)
      x.kind_of?(NullNode)
    end

    # Share the only instance because it's a singleton and immutable object.
    def clone
      self
    end

    def +(node)
      node
    end

    def to_ruby
      "Amrita::Null"
    end

    # NullNode has no children
    def children
      []
    end
  end
  Null = NullNode.instance

  # represents HTML element
  class Element
    include Node
    
    # return attributes as AttrArray
    #
    # CAUTION! never edit result of this method. use []= instead.
    # because it may be shared by other Elements.
    attr_reader :attrs

    # CAUTION! internal use only
    attr_reader :hide_hid

    # return body
    attr_reader :body
    
    # internal use only
    attr_accessor :multi

    # Don't use Element.new. Use Amrita#e instead.
    def initialize(tagname_or_element, *a, &block)
      case tagname_or_element
      when Element
        @tagname = tagname_or_element.tagname_symbol
        @attrs = tagname_or_element.attrs.clone
        @multi = tagname_or_element.multi
        @hide_hid = tagname_or_element.hide_hid
        if block_given?
          init_body(&block)
        else
          @body = tagname_or_element.body.clone
        end
      when Symbol
        set_tag(tagname_or_element)
        @attrs = AttrArray.new
        @hide_hid = false
        if a.size() == 1 and a.kind_of?(AttrArray)
          @attrs = a.clone
        else
          a.each { |aa| put_attr(aa) }
        end
        if block_given?
          init_body(&block)
        else
          @body = Null
        end
      else
        raise TypeError, "tagname must be a Symbol, but #{tagname_or_element.class}, #{tagname_or_element}"
      end
    end

    # test if tagname and attributes and body are equal to self.
    # doesn't concern the order of attributes
    def ==(x)
      return false unless x.kind_of?(Element)
      return true if x.object_id == object_id
      return false unless x.tagname_symbol == @tagname
      return false unless x.attrs.size == @attrs.size
      @attrs.each do |a|
        return false unless x[a.key] == a.value
      end
      return false unless x.body == @body
      true
    end

    def set_tag(tagname)
      raise TypeError if !tagname.is_a?(Symbol)
      if tagname
        @tagname = tagname
      else
        @tagname = nil
      end
    end

    def clone(&block)
      Element.new(self, &block)
    end

    # return Tag as String
    def tagname
      @tagname.id2name
    end

    # return Tag as Symbol
    def tagname_symbol
      @tagname
    end

    # hide hid for internal use (expand).
    def hide_hid!
      @hide_hid = true
    end
    
    def tagclass
      self[:class]
    end

    # set attribule.
    def put_attr(a)
      case a
      when Attr
        @attrs[a.key] = a
      when AttrArray
        a.each do |aa|
          put_attr(aa)
        end
      when Hash
        a.each do |k, v|
          k = k.id2name if k.is_a?(Symbol)
          put_attr(Attr.new(k, v))
        end
      else
        raise "not a Attr, AttrArray or Hash, but a #{a.class}"
      end
    end

    def <<(a, &block)
      put_attr(a)
      init_body(&block) if block_given?
      self
    end

    # test if it has attribule for +key+
    def include_attr?(key)
      @attrs[key] ? true : false
    end

    # return attribule value for +key+
    def [](key)
      raise TypeError if !key.is_a?(String)
      a = @attrs[key]
      if a
        a.value
      else
        nil
      end
    end

    # set attribule. delete it if +value+ is +nil+
    def []=(key, value)
      raise TypeError if !key.is_a?(String)
      if !value
        delete_attr!(key)
      else
        put_attr(Attr.new(key,value))
      end
      value
    end

    # delete attribute of +key+
    def delete_attr!(key)
      @attrs.delete(key)
      self
    end

    def to_ruby
      ret = "e(:#{tagname}#{multi ? " multi" : ""}"
      if attrs.size > 0
        ret << ","
        ret << attrs.collect { |a| a.to_ruby}.join(",")
      end
      ret << ") "
      ret << "{ #{body.to_ruby} }" if body and not body.kind_of?(NullNode)
      ret
    end

    # set the +text+ to body of this Element.
    def set_text(text)
      @body = TextElement.new(text)
    end
      
    def add(node)
      case @body
      when Null
        @body = node
      when NodeArray
        @body << node
      when Element, TextElement, SpecialElement
        a = NodeArray.new()
        a << @body << node
        @body = a
      else
        raise TypeError
      end
    end
  end

  # immutable object
  class TextElement
    include Node

    def initialize(text=nil)
      case text
      when nil
        @text = ""
      when String
        @text = text.frozen_copy
      when TextElement
        @text = x.to_s
      else
        @text = value.to_s.freeze 
      end
    end

    def clone
      self # immutable object can be shared always
    end

    def ==(x)
      if x.is_a?(String)
        return @text == x
      else
        return @text == x.to_s
      end
    end

    def to_ruby
      @text.inspect
    end

    def to_s
      @text
    end
  end

  # represents an Array of Node. It is a Node also.
  class NodeArray
    include Node

    def initialize(*elements)
      if elements.size() == 1 and elements[0].kind_of?(NodeArray)
        @array = elements[0].to_a.collect {|n| n.clone}
      else
        @array = elements.collect do |a|
          #raise "can't be a parent of me!" if a.id == self.id # no recusive check because it costs too much
          to_node(a)
        end
      end
    end

    def ==(x)
      case x
      when NodeArray, Array
        return false unless x.size() == @array.size()
        @array.each_with_index do |n, i|
          return false unless n == x[i]
        end
        true
      else
        false
      end
    end

    def size()
      @array.size()
    end

    def [](index)
      @array[index]
    end

    def no_child?
      @array.empty?
    end

    def each
      @array.each {|e| yield e}
    end
    
    def elements_with_attr(key, value = nil)
      raise TypeError if !key.is_a?(Symbol)
      ret = []
      @array.each {|node|
        if node.is_a?(Element) && (v = node.attrs[key])
          if value && v == value
            ret << node
          end
        end
      }
      return ret
    end

    def to_a
      @array.dup
    end

    def clone
      NodeArray.new(self)
    end

    def children
      @array
    end

    def +(node)
      ret = clone
      ret << node
      ret
    end

    def <<(node)
      raise "can't be a parent of me!" if node.equal?(self)
      case node
      when Array, NodeArray
        node.each {|n| self << n }
      when Node
        @array << node
      else
        @array << TextElement.new(node.to_s)
      end
      self
    end
    alias :add :<<

    def to_ruby
      "[ " + @array.collect {|e| e.to_ruby}.join(", ") + " ]"
    end
  end

  # represents a special tag like a comment.
  class SpecialElement #:nodoc:
    attr_reader :tag, :body
    include Node

    def initialize(tag, body)
      @tag = tag
      @body = body.dup.freeze
    end

    def clone
      SpecialElement.new(@tag, @body)
    end

    def children
      []
    end

    # end tag
    def etag
      case @tag 
      when '!'
        ''
      when '!--'
        '--'
      when '?'
        '?'
      when '![CDATA['
        ']]'
      else
        @tag
      end
    end
      
    def ==(other)
      raise ArgumentError, "#{other} is #{other.class}" if !other.is_a?(SpecialElement)
      if @tag == other.tag && @body == other.body
        return true
      else
        return false
      end
    end

    def to_ruby
      %Q(special_tag(#{@tag.dump}, #{@body.dump}) )
    end
  end
  
  # generate Element object
  #
  
  # [e(:hr)] <hr>
  # [e(:img src="a.png")]  <img src="a.png">
  # [e(:p) { "text" }]  <p>text</p>
  # [e(:span :class=>"fotter") { "bye" } ] <span class="fotter">bye</span>
  
  def e(tagname, *attrs, &block)
    Element.new(tagname, *attrs, &block)
  end
  alias element e
  module_function :e
  module_function :element

  # generate AttrArray object
  def a(*x, &block)
    case x.size
    when 1
      x = x[0]
      case x
      when Hash
      when String
        x = Attr.new(x)
      when Symbol
        x = Attr.new(x.to_s)
      when Attr
      else
        raise(TypeError, "Not Attr,String or Symbol: #{x}")
      end
      AttrArray.new(x, &block)
    when 0
      AttrArray.new([], &block)
    else
      a = (0...x.size/2).collect do |i|
        Attr.new(x[i*2], x[i*2+1])
      end
      AttrArray.new(a, &block)
    end
  end
  alias attr a
  module_function :a
  module_function :attr

  def text(text) #:nodoc:
    TextElement.new(text)
  end
  module_function :text

  def link(href, klass = nil, &block) #:nodoc:
    element("a",&block) << attr(:href, href) 
  end
  module_function :link

  def special_tag(tag, body)
    SpecialElement.new(tag, body)
  end
  module_function :special_tag

  def Amrita::append_features(klass) #:nodoc:
    super
    def klass::def_tag(tagname, *attrs_p)
      def_tag2(tagname, tagname, *attrs_p)
    end

    def klass::def_tag2(methodname, tagname, *attrs_p)
      methodname = methodname.id2name 
      tagname = tagname.id2name 
      attrs = attrs_p.collect { |a| a.id2name }

      if attrs.size > 0
        param = attrs.collect { |a| "#{a}=nil" }.join(", ")
        param += ",*args,&block"
        method_body = "  e(:#{tagname}, "
        method_body += attrs.collect { |a| "A(:#{a}, #{a})"}.join(", ")
        method_body += ", *args, &block)"
      else
        param = "*args, &block"
        method_body = "  e(:#{tagname}, *args, &block) "
      end
      a = "def #{methodname}(#{param}) \n#{method_body}\nend\n"
      #print a
      eval a
    end
  end
end
