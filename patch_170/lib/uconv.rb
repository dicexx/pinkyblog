#! /usr/local/bin/ruby
## uconv wrapper
## (c) 2003 by yoshidam
##
## $Id: uconv.rb,v 1.1.1.1 2003/04/16 14:33:52 yoshidam Exp $

begin
  require 'uconv.so'
rescue LoadError
  require 'rbuconv'
end
