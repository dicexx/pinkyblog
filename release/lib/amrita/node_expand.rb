
# Amrita -- A html/xml template library for Ruby.
# Copyright (c) 2002 Taku Nakajima.
# Licensed under the Ruby's License.

# Copyright (c) 2003-2005, maintenanced by HORIKAWA Hisashi.
#     http://www.nslabs.jp/amrita-altered.rhtml

# -*- encoding:utf-8 -*-

require 'amrita/node'

class Object #:nodoc:
  def amrita_expand_element(e, context)
    ret = e.clone { Amrita::Node::to_node(self.to_s) }
    context.filter_element(ret)
  end

  def amrita_expand_node(n, context)
    Amrita::Node::to_node(self.to_s)
  end
end

class TrueClass #:nodoc:
  def amrita_expand_element(e, context)
    context.filter_element(e)
  end

  def amrita_expand_node(n, context)
    n
  end
end

class NilClass #:nodoc:
  def amrita_expand_element(e, context)
    Amrita::Null
  end

  def amrita_expand_node(n, context)
    Amrita::Null
  end
end

class FalseClass #:nodoc:
  def amrita_expand_element(e, context)
    Amrita::Null
  end

  def amrita_expand_node(n, context)
    Amrita::Null
  end
end

module Enumerable #:nodoc:
  def amrita_expand_element(e, context)
    context.do_copy do
      ret = collect do |d|
        e.clone.expand1(d, context)
      end
      Amrita::Node::to_node(ret)
    end
  end

  def amrita_expand_node(n, context)
    context.do_copy do
      ret = collect do |d|
        n.clone.expand1(d, context)
      end
      Amrita::Node::to_node(ret)
    end
  end
end

class String #:nodoc:
  def amrita_expand_element(e, context)
    ret = e.clone { Amrita::Node::to_node(self) }
    if context.expand_attr
      context.filter_element(ret)
    else
      new_elem = context.filter_element(ret, false)
      new_elem.expand_attr!({}, context)
    end
  end

  def amrita_expand_node(n, context)
    Amrita::Node::to_node(self)
  end
end

class Proc #:nodoc:
  def amrita_expand_element(e, context)
    e = context.filter_element(e.clone, false)
    case arity
    when 1, -1
      call(e)
    when 2
      call(e, context)
    else
      call(e, context)
    end
  end

  def amrita_expand_node(n, context)
    raise Amrita::ModelMisMatch(type, n.class)
  end
end

module Amrita 
  module DictionaryData #:nodoc:
    # 要素を展開する。
    #   e  Elementインスタンス
    def amrita_expand_element(e, context)
      hid = e[context.tmpl_id]
      new_elem = context.filter_element(e.clone, false)
      if context.expand_attr
        new_elem.expand_attr!(self, context)
      else
        new_elem.expand_attr!(self, context) if !hid
      end
      if hid =~ /^\w+$/
        d = amrita_get_data(hid.intern, e, context)
        new_elem.expand1(d, context)
      else
        new_elem.init_body {
          new_elem.body.expand1(self, context)
        }
        new_elem
      end
    end

    # 要素以外を展開する
    #   n  Element以外のNodeサブクラスインスタンス
    def amrita_expand_node(n, context)
      n.apply_to_children(self, context) {|child|
        child.expand1(self, context)
      }
    end
  end
end

class Hash #:nodoc:
  include Amrita::DictionaryData

  # key      id属性値のシンボル
  # element  Elementオブジェクト
  def amrita_get_data(key, element, context)
    self[key]
  end
end

module Amrita

  class ModelMisMatch < RuntimeError
    def initialize(model_type, node_type)
      msg = %Q[#{model_type} can't expand #{node_type}]
      super(msg)
    end
  end

  # a module to be included user's class.
  #
  # 
  #     tmpl = TemplateText.new "<p id=time><em id=year></em></p>\n\n"                
  #     tmpl.expand(STDOUT, {:time => Time.now}) # => <p>Thu Jul 18 14:38:28 JST 2002</p> 
  #                                                                                       
  #     class Time                                                                        
  #       include ExpandByMember                                                          
  #     end                                                                               
  #     tmpl.expand(STDOUT, {:time => Time.now}) # => <p><em>2002</em></p>
  #
  # At first +expand+, 
  # and <tt><em id=year>..</em></tt> was deleted and
  # replaced with the result of +to_s+ methodof of the Time object.
  #
  # At second, the Time object is a +ExpandByMember+ object, so 
  # amrita consider it as a structured object like Hash.
  # <tt><em id=year>..</em></tt> was expanded recursivelly
  # with the Time object. And the +year+ method was called.

  module ExpandByMember 
    include DictionaryData

    def amrita_get_data(key, e, context) #:nodoc:
      m = method(key)
      if m 
        case m.arity
        when 0
          __send__(key)
        when 1
          __send__(key, e)
        else
          __send__(key, e, context)          
        end
      else
        __send__(key)
      end
    end
  end

  # This is the second parametor of the Node#expand method.
  #
  # It controles the behavior of the +expand+
  #
  class ExpandContext 

    # If set, +id+ attribute is deleted after +expand+.
    # Default is true
    attr_reader :delete_id

    # If set, +id+ attribute is deleted on copy
    # Default is true
    attr_accessor :delete_id_on_copy

    # For backword compatibility only
    attr_accessor :expand_attr
    
    attr_accessor :tmpl_id

    attr_reader   :do_delete_id #:nodoc:

    def initialize #:nodoc:
      @do_delete_id = @delete_id = true
      @delete_id_on_copy = true
      @expand_attr = false
      @tmpl_id = "id"
    end

    def delete_id=(flag) #:nodoc:
      @do_delete_id = @delete_id = flag
    end

    def filter_element(e, need_clone_on_modify=true) #:nodoc:
      if @do_delete_id
        e = e.clone if need_clone_on_modify
        e.delete_attr!(@tmpl_id) 
      else
        e.hide_hid!
      end
      e
    end

    def do_copy(&block) #:nodoc:
      save = @do_delete_id
      @do_delete_id = true if delete_id_on_copy
      yield
    ensure
      @do_delete_id = save
    end
  end

  DefaultContext = ExpandContext.new

  class AttrArray
    def amrita_expand_element(e, context) #:nodoc:
      ret = e.clone 
      context.filter_element(ret, false)
      each do |a|      
        ret[a.key] = a.value # replace attributes with model data's
      end
      if body != Null
        ret.expand1(body,context)
      else
        ret
      end
    end

    def amrita_expand_node(n, context)
      raise Amrita::ModelMisMatch(type, n.class)
    end
  end

  module Node


    # expand self as a template with a model +data+.
    def expand(data, context=DefaultContext.clone)
      case data
      when true
        self
      when nil, false
        Null
      when DictionaryData
        expand1(data, context)
      else
        raise "Amrita::Node#expand accepts only Hash or ExpandByMember as model data (#{data.class} was passed)"
      end
    end

    def expand1(data, context)  # :nodoc:
      data.amrita_expand_node(self, context)
    end

    def amrita_expand_element(e, context) #:nodoc:
      e.clone { self }
    end

    def amrita_expand_node(n, context)
      self
    end

    def apply_to_children(hash, context)
      self
    end
  end

  class NullNode
    def expand1(data, context)  # :nodoc:
      self
    end

    def amrita_expand_element(e, context) #:nodoc:
      self
    end

    def amrita_expand_node(n, context)
      self
    end
  end

  class Element
    def expand1(data, context) #:nodoc:
      data.amrita_expand_element(self, context)
    end

    def has_expandable_attr? #:nodoc:
      @attrs.each do |attr|
        next unless attr.value
        return true if attr.value[0] == ?@
      end
      false
    end

    def expand_attr!(data, context) #:nodoc:
      @attrs.each do |attr|
        next if attr.key == context.tmpl_id
        next unless attr.value
        if attr.value[0] == ?@
          self[attr.key] = data.amrita_get_data(attr.value[1..-1].intern, self, context)
        end
      end
      self
    end
    
    def apply_to_children(hash, context)
      clone { yield(body) }
    end
  end

  class NodeArray
    def apply_to_children(hash, context)
      ret = []
      hid = context.tmpl_id

      nodes = to_a()
      while nodes.size > 0
        n = nodes.shift
        if n.is_a?(Element) && n.multi && n.multi.alt &&
                           (ary = hash[n.attrs[hid].value.intern]).is_a?(Array)
          # 配列を交互に展開する
          # self = <table>
          #   n = <tr amrita_id="foo+">
          # hash["foo"] = ["a", "b", ...]
          alt_id = n.attrs[hid].value
          alt_e = [n]
          while (nodes.first.is_a?(Element) && nodes.first.attrs[hid].value == alt_id) || (nodes.first.is_a?(TextElement) && nodes.first.to_s.strip == "")
            f = nodes.shift
            alt_e << f if f.is_a?(Element)
          end
          ary.each_with_index {|data, i|
            ret << alt_e[i % alt_e.size].clone.delete_attr!(hid).expand1(data, context)
          }
        else
          ret << yield(n)
        end
      end
      Node::to_node(ret)
    end
  end

  class FormatterNode #:nodoc:
    def apply_to_children(hash, context)
      clone { yield(body) }
    end
  end
end
