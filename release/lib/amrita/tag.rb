
# Amrita -- A html/xml template library for Ruby.
# Copyright (c) 2002 Taku Nakajima.
# Licensed under the Ruby's License.

# Copyright (c) 2003-2005, maintenanced by HORIKAWA Hisashi.
#     http://www.nslabs.jp/amrita-altered.rhtml

# -*- encoding:utf-8 -*-

if RUBY_VERSION >= "1.8"
  require "set"
else
  class Set
    def initialize(args)
      @h = {}
      args.each do |a|
        @h[a] = true
      end
    end

    def add(o)
      @h[o] = true
      self
    end
    alias :<< :add

    def |(a)
      ret = clone
      a.each do |aa|
        ret.add(aa)
      end
      ret
    end
    alias :+ :|

    def delete(o)
      if @h[o]
        @h[o] = false
        self
      else
        nil
      end
    end

    def -(a)
      ret = clone
      a.each {|o|
        ret.delete(o)
      }
      ret
    end

    def each(&block)
      @h.each_key(&block)
    end

    def to_a
      @h.keys
    end

    def include?(x)
      @h[x] == true
    end
  end
end

module Amrita

  # This class provide information for formatting.
  class TagInfo
    class TagInfoItem
      attr_reader :tagname

      # pptype specfies pretty print type.
      # This value should be one of these.
      #
      #        FORMAT 1                         
      #           |.....                        
      #           |<tag>                        
      #           |.....                        
      #           |</tag>                       
      #           |......                       
      #        FORMAT 2                         
      #           |.....                        
      #           |<tag>......</tag>            
      #           |.....                        
      #        FORMAT 3                         
      #           |.....<tag>......</tag>.....  
      #           |                             
      # 
      #  Default is 3                                        
      attr_accessor :pptype, :tag_class
      attr_accessor :tag

      # If true, it will be printed <hr> not <hr></hr>
      attr_accessor :empty_tag

      def initialize(tagname, pptype=3)
        @pptype = pptype
        @url_attributes = nil
        @empty_tag = false
        @tag_class = nil
      end

      def freeze
        @pptype.freeze

        @url_attributes.freeze
        @empty_tag.freeze
        super
        self
      end

      def set_url_attr(*names)
        @url_attributes ||= {}
        names.each do |n|
          @url_attributes[n] = true
        end
      end

      # check if this attribute can have url as value.
      def url_attr?(attr_name)
        return false unless @url_attributes
        case attr_name
        when nil 
          return false
        when Symbol
        when String
          attr_name = attr_name.intern
        else
          attr_name = attr_name.to_s.intern
        end
        @url_attributes[attr_name]
      end
    end

    DefaultTagInfo = TagInfoItem.new(nil).freeze

    def initialize
      @dict = Hash.new(DefaultTagInfo)
    end

    def freeze
      @dict.each do |k,v|
        k.freeze
        v.freeze
      end
      self
    end

    def get_tag_info(tagname)
      case tagname
      when Symbol
      when String
        tagname = tagname.downcase.intern
      else
        raise TypeError
      end
      if @dict.has_key?(tagname)
        @dict[tagname]
      else
        @dict[tagname] = TagInfoItem.new(tagname)
      end
    end
    alias [] get_tag_info
    
    def empty_tag?(element)
      raise TypeError if !element.is_a?(Element)
      get_tag_info(element.tagname_symbol).empty_tag
    end
    
    def accept_child?(element, name)
      raise TypeError if !element.is_a?(Element)

      taginfo = get_tag_info(element.tagname_symbol)
      taginfo.tag = (taginfo.tag_class || Tag).new(element.tagname) if !taginfo.tag
      return taginfo.tag.accept_child(name)
    end

    def url_attr?(element, attr)
      raise TypeError if !element.is_a?(Element)
      raise TypeError if !attr.is_a?(Attr)
      get_tag_info(element.tagname_symbol).url_attr?(attr.key)
    end
  end

  # but it has tag information so moved to here(tag.rb)
  class Tag	
    attr_reader :name, :attrs
    def initialize(name, attrs=[])
      @name = name.downcase
      @attrs = attrs
    end

    def to_s
      if attrs.size > 0
        "<#{@name} " + attrs.collect { |a| "#{a[0]}='#{a[1]}'" }.join(" ") + ">"
      else
        "<#{@name}>"
      end
    end

    def ==(t)
      t.kind_of?(Tag) and name == t.name and attrs == t.attrs
    end
    
    # 開始タグまたは空要素タグ
    def start_tag?
      @name[0] != ?/
    end

    def end_tag?
      @name[0] == ?/
    end
    
    def empty_tag?
      HtmlTagInfo::EMPTY.include?(@name)
    end

    def generate_element(parser)
      a = attrs.collect { |attr| Attr.new(attr[0], attr[1]) }
      if empty_tag?
        Element.new(name, *a)
      else
        Element.new(name, *a) do
          parser.parse1(self)
        end
      end
    end

    def accept_child(child_tag)
      true
    end

    def can_omit_endtag?
      HtmlTagInfo::CAN_OMIT_ENDTAG.include?(@name)
    end
  end

  class TagInline < Tag
    def accept_child(child_tag)
      not HtmlTagInfo::BLOCK_OR_ITEM.include?(child_tag)
    end
  end

  class TagBlock < Tag    
    def accept_child(child_tag)
      true
    end
  end

  class TagEmpty < Tag
    def accept_child(child_tag)
      false
    end
  end

  class TagList < Tag
    def accept_child(child_tag)
      true
    end
  end

  class TagItem < Tag
    def accept_child(child_tag)
      raise TypeError if !child_tag.is_a?(String)
      child_tag != @name
    end
  end

  class TagP < Tag
    def accept_child(child_tag)
      not HtmlTagInfo::BLOCK.include?(child_tag)
    end
  end

  class TagThTd < Tag
    def accept_child(child_tag)
      !["th", "td", "tr", "tfoot", "tbody"].include?(child_tag)
    end
  end

  class TagTr < Tag
    def accept_child(child_tag)
      !["tr", "tfoot", "tbody"].include?(child_tag)
    end
  end

  class TagColgroup < Tag
    def accept_child(child_tag)
      !["colgroup", "thead", "tfoot", "tbody", "tr"].include?(child_tag)
    end
  end

  class TagTableSection < Tag
    def accept_child(child_tag)
      case child_tag
      when "tbody", "thead", "tfoot"
        false
      else
        true
      end
    end
  end

  class TagDT < Tag
    def accept_child(child_tag)
      not (child_tag == "dt" or child_tag == "dd")
    end
  end

  class TagDD < Tag
    def accept_child(child_tag)
      not (child_tag == "dt" or child_tag == "dd")
    end
  end

  class TagPre < TagBlock
    def generate_element(parser)
      a = attrs.collect { |attr| Attr.new(attr[0], attr[1]) }
      Amrita::pre(*a) { parser.parse1(self) }
    end
  end

  class TagOption < Tag
    def accept_child(child_tag)
      child_tag != "option" && child_tag != "optgroup"
    end
  end

  class HtmlTagInfo < TagInfo
    include Amrita

    EMPTY = Set.new(%w(area base basefont bgsound br col frame hr img input isindex 
	         keygen link meta nextid param spacer wbr))
    INLINE = Set.new(%w(em tt i b u strike s big small strong dfn code samp kbd var cite abbr acronym sub))
    BLOCK = Set.new(%w(address dl isindex p blockquote fieldset menu pre center form noframes table dir
                 h1 h2 h3 h4 h5 h6 noscript ul div hr ol))
    LIST = Set.new(%w(ul ol dir))
    ITEM = Set.new(%w(li dt dd tr th td))
    ACCEPT_ANY = Set.new(%w(html head body td))
    BLOCK_OR_ITEM = (BLOCK | ITEM)
    BLOCK_OR_EMPTY = (BLOCK | EMPTY)
    CAN_OMIT_ENDTAG = Set.new(%w(html head body p li tr th td thead tbody tfoot colgroup dt dd option))

    def initialize
      super

      pptype1 = %w(html head body table ul ol div br table tr)
      pptype1.each do |name|
        get_tag_info(name).pptype = 1
      end

      pptype2 = %w(title link meta tr li th td h1 h2 h3 h4 h5 h6 p)
      pptype2.each do |name|
        get_tag_info(name).pptype = 2
      end
      empty = %w(area base basefont bgsound br col frame hr img input isindex 
	         keygen link meta nextid param spacer wbr) 
      empty.each do |name|
        get_tag_info(name).empty_tag = true
      end

      get_tag_info(:a).set_url_attr(:href)
      get_tag_info(:base).set_url_attr(:href)
      get_tag_info(:img).set_url_attr(:src)
      get_tag_info(:img).set_url_attr(:usemap)
      get_tag_info(:form).set_url_attr(:action)
      get_tag_info(:link).set_url_attr(:href)
      get_tag_info(:area).set_url_attr(:href)
      get_tag_info(:body).set_url_attr(:background)
      get_tag_info(:script).set_url_attr(:src)
      get_tag_info(:object).set_url_attr(:classid)
      get_tag_info(:object).set_url_attr(:codebase)
      get_tag_info(:object).set_url_attr(:data)
      get_tag_info(:object).set_url_attr(:archive)
      get_tag_info(:object).set_url_attr(:usemap)
      get_tag_info(:applet).set_url_attr(:codebase)
      get_tag_info(:applet).set_url_attr(:archive)
      get_tag_info(:applet).set_url_attr(:usemap)
      get_tag_info(:q).set_url_attr(:cite)
      get_tag_info(:blockquote).set_url_attr(:cite)
      get_tag_info(:ins).set_url_attr(:cite)
      get_tag_info(:del).set_url_attr(:cite)
      get_tag_info(:frame).set_url_attr(:longdesc)
      get_tag_info(:frame).set_url_attr(:src)
      get_tag_info(:iframe).set_url_attr(:longdesc)
      get_tag_info(:iframe).set_url_attr(:src)
      get_tag_info(:head).set_url_attr(:profile)

      BLOCK.each do |t| 
        get_tag_info(t).tag_class = TagBlock 
      end

      INLINE.each do |t| 
        get_tag_info(t).tag_class = TagInline
      end

      EMPTY.each do |t| 
        get_tag_info(t).tag_class = TagEmpty
      end

      LIST.each do |t| 
        get_tag_info(t).tag_class = TagList
      end

      ITEM.each do |t| 
        get_tag_info(t).tag_class = TagItem
      end

      %w(thead tbody tfoot).each do |t|
        get_tag_info(t).tag_class = TagTableSection
      end

      %w(dt dd).each do |t|
        get_tag_info(t).tag_class = TagDT
      end

      get_tag_info(:pre).tag_class = TagPre
      get_tag_info(:p).tag_class = TagP
      get_tag_info(:th).tag_class = TagThTd
      get_tag_info(:td).tag_class = TagThTd
      get_tag_info(:tr).tag_class = TagTr
      get_tag_info(:colgroup).tag_class = TagColgroup
      get_tag_info(:option).tag_class = TagOption
    end
  end

  DefaultHtmlTagInfo = HtmlTagInfo.new

end

