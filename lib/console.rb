#!/usr/bin/env ruby

require_relative 'coin.rb'
require 'pry'

c=Coin.new(:coinname => 'bitcoin',:defport => 8332)
c.init

binding.pry


