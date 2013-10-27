#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class CoinRPC
	def initialize(service_url)
		@uri = URI.parse(service_url)
	end

	def method_missing(name, *args)
		post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
		# puts post_body
		resp = JSON.parse( http_post_request(post_body), {:quirks_mode => true} )
		# puts resp
		raise JSONRPCError, resp['error'] if resp['error']
		resp['result']
	end

	def http_post_request(post_body)
		http    = Net::HTTP.new(@uri.host, @uri.port)
		request = Net::HTTP::Post.new(@uri.request_uri)
		request.basic_auth @uri.user, @uri.password
		request.content_type = 'application/json'
		request.body = post_body
		http.request(request).body
	end

	class JSONRPCError < RuntimeError 
	end
end

class Coin 
	def initialize(*h)
		if h.length == 1 && h.first.kind_of?(Hash)
			@parm=h.first
		else 
			@parm=Hash.new
		end
	end

	def init
		self.getconfigfile
		self.readconfig
		@user=@config['rpcuser'] ||= @config['rpcpassword'] ||= self.currency
		@password=@config['rpcpassword'] ||= self.currency
		self.setserver
		@rpc = CoinRPC.new(@url)
	end

	def rpc
		return @rpc
	end
	
	def parm
		return @parm
	end
	
	def determineurl
		@url="http://#{@user}:#{@password}@#{@server}:#{@port}"
		# puts @url
	end

	def currency
		if @parm.has_key?(:coinname) 
			return @parm[:coinname]
		else
			return "unknown"
		end
	end

	def getconfigfile
		@configfile="#{ENV['HOME']}/.#{self.currency}/#{self.currency}.conf"
	end

	def readconfig
		@config=Hash[*File.read(@configfile).split(/[=\n]+/)]
	end

	def server
		return @server
	end

	def port
		return @port
	end

	def setserver
		if @parm.has_key?('server') then
			@server = @parm['server']
		else
			if @config.has_key?('rpcconnect') then
				@server = @config['rpcconnect']
			else
				@server = 'localhost'
			end
		end
		if @parm.has_key?('port') then
			@port = @parm['port']
		else
			if @config.has_key?('rpcport') then
				@port = @config['rpcport']
			else
				@port = @parm[:defport]
			end
		end
		self.determineurl
	end

	def defport
		return 0
	end
end
