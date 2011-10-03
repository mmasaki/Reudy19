#encoding: utf-8
#Copyright (C) 2011 Glass_saga <glass.saga@gmail.com>

$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR)

CONSUMER = { #get it in http://twitter.com/oauth_client/new
      :key => "key",
      :secret => "secret"
      }

Interval = 60 # タイムラインを取得する間隔

trap(:INT){ exit }

require 'optparse'
require 'rubytter'
require 'highline'
require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'
require $REUDY_DIR+'/reudy_common'

module Gimite
  class TwitterClient
    
    include(Gimite)
    
    def initialize(user)
      @user = user
      @user.client = self
      @last_tweet = Time.now
      
      cons = OAuth::Consumer.new(CONSUMER[:key],CONSUMER[:secret], :site => "http://api.twitter.com")
  
      unless File.exist?(File.dirname(__FILE__)+"/token")
        request_token = cons.get_request_token
        puts "Access This URL and press 'Allow' => #{request_token.authorize_url}"
        pin = HighLine.new.ask('Input key shown by twitter: ')
        access_token = request_token.get_access_token(:oauth_verifier => pin)
        open(File.dirname(__FILE__)+"/token","w") do |f|
          f.puts access_token.token
          f.puts access_token.secret
        end
      end
  
      keys = File.read(File.dirname(__FILE__)+"/token").split(/\r?\n/).map(&:chomp)
  
      token = OAuth::AccessToken.new(cons, keys[0], keys[1])
  
      @r = OAuthRubytter.new(token)
    end
    
    attr_accessor :r
  
    def onTweet(status)
      @user.onOtherSpeak(status.user.screen_name, status.text)
    end
    
    #補助情報を出力
    def outputInfo(s)
      puts "(#{s})"
    end
    
    #発言する
    def speak(s)
      time = Time.now
      if time - @last_tweet > 60
        @r.update(s)
        puts "tweeted: #{s}"
        @last_tweet = time
      end
    end
  end
  
  opt = OptionParser.new
    
  directory = 'public'
  opt.on('-d DIRECTORY') do |v|
    directory = v
  end
  
  db = 'pstore'
  opt.on('--db DB_TYPE') do |v|
    db = v
  end
  
  mecab = nil
  opt.on('-m','--mecab') do |v|
    mecab = true
  end
  
  opt.parse!(ARGV)  
  
  #twitter用ロイディを作成
  client = TwitterClient.new(Reudy.new(directory,{},db,mecab))
    
  loop do
    begin
      client.r.friends_timeline.each do |status|
        puts "#{status.user.screen_name}: #{status.text}"
        client.onTweet(status)
      end
      sleep(Interval)
    rescue => ex
      if ex.message == "Could not authenticate with OAuth." || ex.message.include?("Rate limit exceeded.")
        abort ex.message
      else
        puts ex.message
      end
    end
  end
end
