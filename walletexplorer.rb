#!/usr/bin/env ruby

require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
require 'erb'
require_relative 'lib/coin.rb'

set :port, 8081
# set :environment, :production
set :bind, '0.0.0.0'

helpers do
  alias_method :h, :escape_html
end

class String
	def to_bool
		return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
		return false if self == false || self.empty? || self =~ (/(false|f|no|n|0)$/i)
		raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
	end
end

get '/' do
	redirect '/coins'
end

get '/coins' do
	items = Array.new
	coins=[
		{:coin => 'bitcoin',:port=>8332},
		{:coin => 'litecoin',:port=>9333},
		{:coin => 'chncoin',:port=>8106},
		{:coin => 'devcoin',:port=>52332},
		{:coin => 'feathercoin',:port=>9337},
		{:coin => 'groupcoin',:port=>51332},
		{:coin => 'i0coin',:port=>7332},
		{:coin => 'ixcoin',:port=>8338},
		{:coin => 'namecoin',:port=>8336},
		{:coin => 'ppcoin',:port=>9902},
		{:coin => 'terracoin',:port=>13332}
	]
	coins.each { |coin|
		item=Hash.new
		item['coin']=coin[:coin]
		c=Coin.new(:coinname => coin[:coin],:defport => coin[:port]) 
		c.init
		# item['balance']=c.rpc.getbalance
		item['balance']="Unknown"
		item['link']="/coin/#{c.server}/#{c.port}/#{c.currency}/getbalance"
		item['json']="/json/coin/#{c.server}/#{c.port}/#{c.currency}/balance"
		items.push(item)
	}
	erb :balances, :locals => {:title => 'Coins', :items => items}	
end

get '/json/coin/:server/:port/:coin/:action' do
	c=Coin.new(:coinname => params[:coin],'server' => params[:server], 'port' => params[:port])
	c.init
	if params[:action] == "balance" then
		items=Hash.new
		items["coin"]=c.currency
		begin 
		items["balance"]=c.rpc.getbalance
		rescue
		item['balance']='Error. Check both rpcuser and rpcpassword for the coin!'
		puts "Error submitting RPC request for #{coin[:coin]}"
		end
		return JSON.generate(items)
	end
end


	
get '/coin/:server/:port/:coin/:action' do
	locals=Hash.new
	locals[:title]=params[:coin] + " - " + params[:action]
	c=Coin.new(:coinname => params[:coin],'server' => params[:server], 'port' => params[:port])
	c.init
	coinlinks=[
		{"content" => "get balance", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/getbalance"},
		{"content" => "list accounts", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listaccounts"},
		{"content" => "list transactions", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions"},
		{"content" => "list received by address", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listreceivedbyaddress"},
		{"content" => "list received by account", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listreceivedbyaccount"}
	]
	locals[:coinlinks]=coinlinks

	if params[:action] == "info" then
		account=params['1'] || '*'
		minconf=(params['2'] || '1').to_i
		items=Array.new
		item=Hash.new
		item['coin']=c.currency
		item['balance']=c.rpc.getbalance(account,minconf)
		item['link']="/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions"
		items.push(item)
		locals[:items] = items
		content=erb :balances, :locals => locals
	elsif params[:action] == "getbalance" then
		account=params['1'] || '*'
		minconf=(params['2'] || '1').to_i
		balance=c.rpc.getbalance(account,minconf)
		items=Array.new
		item=Hash.new
		item["coin"]=c.currency
		item["account"]=account
		item["balance"]=balance
		item["transactions"]="/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions?1=#{account}"
		items.push(item)
		hitems=['coin','account','balance']
		locals[:items] = items
		locals[:hitems] = hitems
		content=erb :generictable, :locals => locals
	elsif params[:action] == "listaccounts" then
		minconf=(params['1'] || '1').to_i
		ritems=c.rpc.listaccounts(minconf)
		items=Array.new
		ritems.each_pair { |k,v|
			item=Hash.new
			item["account"]=k
			item["balance"]=v
			item["transactions"]="/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions?1=#{k}"
			items.push(item)
		}
		hitems=['account','balance']
		locals[:items] = items
		locals[:hitems] = hitems
		content=erb :generictable, :locals => locals
	elsif params[:action] == "listtransactions" then
		account=params['1'] || '*'
		count=(params['2'] || '10').to_i
		from=(params['3'] || '0').to_i

		prevone=from-count
		prevone=0 if prevone<0
		nextone=from+count
			
		tablelinks=[ {"content" => "all", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions?1=#{account}&2=999999&3=0"}]
		
		items=c.rpc.listtransactions(params['1'] || '*',(params['2'] || '10').to_i,(params['3'] || '0').to_i)
		items.each_with_index { |item,i|
			items[i]['htime']=Time.at(items[i]['time'] || 0)
			items[i]['htimereceived']=Time.at(items[i]['timereceived'] || 0)
		}
		if from > 0 then
			tablelinks.push({"content" => "prev", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions?1=#{account}&2=#{count}&3=#{prevone}"})
		end
		if items.count >= count then
			tablelinks.push({"content" => "next", "href" => "/coin/#{c.server}/#{c.port}/#{c.currency}/listtransactions?1=#{account}&2=#{count}&3=#{nextone}"})
		end

		hitems=['account','address','amount','htime']
		locals[:items] = items
		locals[:hitems] = hitems
		locals[:tablelinks] = tablelinks
		locals[:count] = count
		locals[:from] = from
		content=erb :generictable, :locals => locals
	elsif params[:action] == "listreceivedbyaddress" then
		items=c.rpc.listreceivedbyaddress((params['1'] || '0').to_i,(params['2'] || 'true').to_bool)
		hitems=['address','account','amount','confirmations']
		locals[:items] = items
		locals[:hitems] = hitems
		content=erb :generictable, :locals => locals
	elsif params[:action] == "listreceivedbyaccount" then
		items=c.rpc.listreceivedbyaccount((params['1'] || '0').to_i,(params['2'] || 'true').to_bool)
		hitems=['account','amount','confirmations']
		locals[:items] = items
		locals[:hitems] = hitems
		content=erb :generictable, :locals => locals
	else
		content=erb :generictable, :locals => locals
	end
	content
end

