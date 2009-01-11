#! /usr/local/bin/ruby
## rbuconv_w32 - Unicode converter for Win32
## (c) 2003 by yoshidam
##
## $Id: rbuconv_w32.rb,v 1.3 2003/04/26 05:24:23 yoshidam Exp $

require 'rbuconv'
require 'Win32API'
require 'nkf'

module Uconv
  MultiByteToWideChar = Win32API.new('KERNEL32', 'MultiByteToWideChar',
                                     ['I', 'L', 'P', 'I', 'P', 'I'], 'I')
  WideCharToMultiByte = Win32API.new('KERNEL32', 'WideCharToMultiByte',
                                     ['I', 'L', 'P', 'I', 'P', 'I', 'P', 'P'],
                                     'I')
  SJIS_CODEPAGE = 932

  module_function

  undef sjistoucs
  def sjistoucs(s)
    ## get converted length
    rlen = MultiByteToWideChar.Call(SJIS_CODEPAGE, 0, s, s.length, nil, 0)
    ret = "\0" * (rlen*2)
    MultiByteToWideChar.Call(SJIS_CODEPAGE, 0, s, s.length, ret, rlen)
    ret.unpack('v*')
  end
  private :sjistoucs

  undef ucstosjis
  def ucstosjis(u)
    us = u.pack('v*')
    ## get converted length
    slen = WideCharToMultiByte.Call(SJIS_CODEPAGE, 0, us, u.length, nil, 0, nil, nil)
    s = "\0"*slen
    WideCharToMultiByte.Call(SJIS_CODEPAGE, 0, us, u.length, s, slen, nil, nil)
    s
  end
  private :ucstosjis


  undef euctoucs
  def euctoucs(s)
    sjistoucs(NKF.nkf('-Esx', s))
  end
  private :euctoucs

  undef ucstoeuc
  def ucstoeuc(u)
    NKF.nkf('-Sex', ucstosjis(u))
  end
  private :ucstoeuc
end
