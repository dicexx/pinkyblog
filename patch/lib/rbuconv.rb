#! /usr/local/bin/ruby
## rbuconv - Pure Ruby Unicode converter
## (c) 2003 by yoshidam
##
## $Id: rbuconv.rb,v 1.3 2003/05/15 15:22:43 yoshidam Exp $

module Uconv
  class Error < StandardError; end

  module_function

  ## UTF-8, UTF-16 and USC-4 (UTF-32)

  REPLACEMENT_CHAR = 0xfffd

  def combineSurrogatePair(ary)
    i = 0
    len = ary.length
    ret = []
    while i < len
      c = ary[i]
      if c >= 0xd800 && c <= 0xdbff &&
          i + 1 < len && ary[i+1] >= 0xdc00 && ary[i+1] <= 0xdfff
        i += 1
        low = ary[i]
        c = (((c & 1023)) << 10 | (low & 1023)) + 0x10000
      end
      ret << c
      i += 1
    end
    ret
  end
  private :combineSurrogatePair

  def divideSurrogatePair(ary)
    i = 0
    len = ary.length
    ret = []
    while i < len
      c = ary[i]
      if c < 0x10000
        ret << c
##      elsif c >= 0xd800 && c<= dfff
      elsif c >= 0x10000 && c <= 0x10ffff
        hi = ((c - 0x10000) >> 10) | 0xd800
        low = (c & 1023) | 0xdc00
        ret << hi
        ret << low
      else
#        raise Uconv::Error.new("non-UTF-16 char detected")
        ret << REPLACEMENT_CHAR
      end
      i += 1
    end
    ret
  end
  private :divideSurrogatePair


  def u8tou16(str)
    ret = (divideSurrogatePair(str.unpack('U*')).pack('v*') rescue
           raise Uconv::Error.new($!))
         
    ret.taint if str.tainted?
    ret
  end
  alias :u8tou2 :u8tou16

  def u8tou4(str)
    ret = (str.unpack('U*').pack('V*') rescue raise Uconv::Error.new($!))
    ret.taint if str.tainted?
    ret
  end

  def u16tou8(str)
    ret = combineSurrogatePair(str.unpack('v*')).pack('U*')
    ret.taint if str.tainted?
    ret
  end
  alias :u2tou8 :u16tou8

  def u16tou4(str)
    ret = combineSurrogatePair(str.unpack('v*')).pack('V*')
    ret.taint if str.tainted?
    ret
  end

  def u4tou8(str)
    ret = str.unpack('V*').pack('U*')
    ret.taint if str.tainted?
    ret
  end

  def u4tou16(str)
    ret = divideSurrogatePair(str.unpack('V*')).pack('v*')
    ret.taint if str.tainted?
    ret
  end

  def u16swap(str)
    ret = str.unpack('n*').pack('v*')
    ret.taint if str.tainted?
    ret
  end
  alias :u2swap :u16swap

  def u16swap!(str)
    str[0..-1] = u16swap(str)
  end
  alias :u2swap! :u16swap!

  def u4swap(str)
    ret = str.unpack('N*').pack('V*')
    ret.taint if str.tainted?
    ret
  end

  def u4swap!(str)
    str[0..-1] = u4swap(str)
  end


  ## Japanese

  UNKNOWN_CHAR = '?'

  def getEUCJPtoUCSMap
    if !defined?(@@EUCJPtoUCSMap)
      puts "loading..." if $DEBUG
      require 'uconv/eucjp_ucs'
    end
    @@EUCJPtoUCSMap
  end
  private :getEUCJPtoUCSMap

  def getEUCJPHojotoUCSMap
    if !defined?(@@EUCJPHojotoUCSMap)
      puts "loading..." if $DEBUG
      require 'uconv/eucjphojo_ucs'
    end
    @@EUCJPHojotoUCSMap
  end
  private :getEUCJPtoUCSMap

  def getUCStoEUCJPMap
    if !defined?(@@UCStoEUCJPMap)
      puts "loading..." if $DEBUG
      require 'uconv/ucs_eucjp'
    end
    @@UCStoEUCJPMap
  end
  private :getUCStoEUCJPMap

  def getCP932toUCSMap
    if !defined?(@@CP932toUCSMap)
      puts "loading..." if $DEBUG
      require 'uconv/cp932_ucs'
    end
    @@CP932toUCSMap
  end
  private :getCP932toUCSMap

  def getUCStoCP932Map
    if !defined?(@@UCStoCP932Map)
      puts "loading..." if $DEBUG
      require 'uconv/ucs_cp932'
    end
    @@UCStoCP932Map
  end
  private :getUCStoCP932Map


  ##   EUC-JP
  def euctoucs(str)
    i = 0
    len = str.length
    ret = []
    map = getEUCJPtoUCSMap
    hmap = getEUCJPHojotoUCSMap
    while i < len
      c = str[i]
      if c <= 0x7f
        ret << c
      elsif c >=  0xa0 && c <= 0xfe
        u = REPLACEMENT_CHAR
        if i + 1 < len
          u = 0
          i += 1
          hi = c & 0x7f
          low = str[i] & 0x7f
          if hi >= 32 && low >= 32
            pos = ((hi - 32) * 96 + (low - 32))*2
            u = (map[pos] << 8) | map[pos + 1]
          end
          ## unknown JIS X 0208 character
          if u == 0
            if respond_to?(:unknown_euc_handler)
              u = unknown_euc_handler([hi, low].pack("cc"))
            else
              u = REPLACEMENT_CHAR
            end
          end
        end
        ret << u
      elsif c == 0x8e
        u = REPLACEMENT_CHAR
        if i + 1 < len
          i += 1
          kana = str[i]
          if kana >= 0xa1 && kana <= 0xdf
            u = 0xff00 | (kana - 0x40)
          end
        end
        ret << u
      elsif c == 0x8f
        u = REPLACEMENT_CHAR
        if i + 2 < len
          u = 0
          i += 1
          hi = str[i] & 0x7f
          i += 1
          low = str[i] & 0x7f
          if hi >= 32 && low >= 32
            pos = ((hi - 32) * 96 + (low - 32))*2
            u = (hmap[pos] << 8) | hmap[pos + 1]
          end
          ## unknown JIS X 0212 character
          if u == 0
            if respond_to?(:unknown_euc_handler)
              u = unknown_euc_handler([c, hi, low].pack("ccc"))
            else
              u = REPLACEMENT_CHAR
            end
          end
        end
        ret << u
      else
        ## invalid character
        ret << REPLACEMENT_CHAR
      end
      i += 1
    end
    ret
  end
  private :euctoucs

  def ucstoeuc(ary)
    map = getUCStoEUCJPMap
    i = 0
    len = ary.length
    ret = ''
    while i < len
      u = ary[i]
      e = 0
      if u < 0x10000
        pos = u*2
        e = (map[pos] << 8) | map[pos + 1]
      end
      if e == 0
        ## unknown UCS character
        if respond_to?(:unknown_unicode_handler)
          ret << unknown_unicode_handler(u)
        else
          ret << UNKNOWN_CHAR
        end
      elsif e <= 127
        ## US-ASCII
        ret << e.chr
      elsif e >= 0xa0a0 && e <= 0xfffe
        ## JIS X 0208
        ret << (e >> 8).chr + (e & 0xff).chr
      elsif e >= 0xa0 && e <= 0xdf
        ## JIS X 0201 Kana
        ret << "\x8e" + e.chr
      elsif e >= 0x2121 && e <= 0x6d63
        ## JIS X 0212
        ret << "\x8f" + ((e >> 8)|0x80).chr + ((e & 0xff)|0x80).chr
      else
        ## invalid table
        if respond_to?(:unknown_unicode_handler)
          ret << unknown_unicode_handler(u)
        else
          ret << UNKNOWN_CHAR
        end
      end
      i += 1
    end
    ret
  end
  private :ucstoeuc

  def euctou8(str)
    ret = euctoucs(str).pack('U*')
    ret.taint if str.tainted?
    ret
  end

  def euctou16(str)
    ret = euctoucs(str).pack('v*')
    ret.taint if str.tainted?
    ret
  end
  alias :euctou2 :euctou16

  def u8toeuc(str)
    ret = (ucstoeuc(str.unpack('U*')) rescue raise Uconv::Error.new($!))
    ret.taint if str.tainted?
    ret
  end

  def u16toeuc(str)
    ret = ucstoeuc(combineSurrogatePair(str.unpack('v*')))
    ret.taint if str.tainted?
    ret
  end
  alias :u2toeuc :u16toeuc

  ##   Shift_JIS (CP932)
  def sjistoucs(str)
    i = 0
    len = str.length
    ret = []
    map = getCP932toUCSMap
    while i < len
      c = str[i]
      if c <= 0x7f
        ret << c
      elsif c >= 0x80 && c <= 0xfc
        u = REPLACEMENT_CHAR
        if i+1 < len && str[i+1] >= 0x40 && str[+1] <= 0xfc
          u = 0
          i += 1
          hi = c
          low = str[i]
          if hi >= 0xe0
            pos = (hi - 0xc1)*188
          else
            pos = (hi - 0x81)*188
          end
          if low >= 0x80
            pos += low - 0x41
          else
            pos += low - 0x40
          end
          if pos < 11280
            pos = pos * 2
            u = (map[pos] << 8) | map[pos + 1]
          end
          if u == 0
            ## unknown SJIS character
            if respond_to?(:unknown_sjis_handler)
              u = unknown_sjis_handler([hi, low].pack('cc'))
            else
              u = REPLACEMENT_CHAR
            end
          end
        end
        ret << u
      elsif c >= 0xa0 && c <= 0xdf
        u = 0xff00 | (c - 0x40)
        ret << u
      else
        ## invalid character
        ret << REPLACEMENT_CHAR
      end
      i += 1
    end
    ret
  end

  def ucstosjis(ary)
    map = getUCStoCP932Map
    i = 0
    len = ary.length
    ret = ''
    while i < len
      u = ary[i]
      s = 0
      if u < 0x10000
        pos = u*2
        s = (map[pos] << 8) | map[pos + 1]
      end
      if s ==  0
        ## unknown UCS character
        if respond_to?(:unknown_unicode_handler)
          ret << unknown_unicode_handler(u)
        else
          ret << UNKNOWN_CHAR
        end
      elsif s <= 127
        ## JIS X 0201 (US-ASCII)
        ret << s.chr
      elsif s >= 0x8140 && s <= 0xfffe
        ## JIS X 0208
        ret << (s >> 8).chr + (s & 0xff).chr
      elsif s >= 0xa0 && s <= 0xdf
        ## JIS X 0201 Kana
        ret << s.chr
      else
        ## invalid table
        if respond_to?(:unknown_unicode_handler)
          ret << unknown_unicode_handler(u)
        else
          ret << UNKNOWN_CHAR
        end
      end
      i += 1
    end
    ret
  end
  private :ucstosjis


  def sjistou8(str)
    ret = sjistoucs(str).pack('U*')
    ret.taint if str.tainted?
    ret
  end

  def sjistou16(str)
    ret = sjistoucs(str).pack('v*')
    ret.taint if str.tainted?
    ret
  end
  alias :sjistou2 :sjistou16

  def u8tosjis(str)
    ret = (ucstosjis(str.unpack('U*')) rescue raise Uconv::Error.new($!))
    ret.taint if str.tainted?
    ret
  end

  def u16tosjis(str)
    ret = ucstosjis(combineSurrogatePair(str.unpack('v*')))
    ret.taint if str.tainted?
    ret
  end
  alias :u2tosjis :u16tosjis

  def eliminate_zwnbsp
    false
  end

  def eliminate_zwnbsp=(arg)
    raise NotImplementedError.new("not implemented")
  end

  def shortest
    false
  end

  def shortest=(arg)
    raise NotImplementedError.new("not implemented")
  end

  def replace_invalid
    true
  end

  def replace_invalid=(arg)
    raise NotImplementedError.new("not implemented")
  end
end
