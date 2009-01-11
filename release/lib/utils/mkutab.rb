#! /usr/local/bin/ruby
## mkutab - Make uconv table from e2u.h, u2e.h, ...
## (c) 2003 by yoshidam
##
## $Id: mkutab.rb,v 1.1.1.1 2003/04/16 14:33:53 yoshidam Exp $

open("|cpp -DCOMPAT_WIN32API -DUSE_FULLWIDTH_REVERSE_SOLIDUS #{ARGV[0]}") do |f|
  out = ''
  outlen = 0
  while l = f.gets
    next if l !~ /^  0x([0-9a-f]*)/
    out << [$1.hex].pack("n")
    outlen += 1
    if outlen == 8
      d = out.dump
      d.gsub!(/\\000(?![0-7])/, '\\\0')
      puts '    ' + d + ' \\'
      out = ''
      outlen = 0
    end
  end
end
