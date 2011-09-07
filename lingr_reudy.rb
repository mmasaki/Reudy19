$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR) #スクリプトがあるディレクトリ

require 'sinatra'
require 'json'
require $REUDY_DIR+'/reudy'

class Lingr
  def initialize
    @message = ""
  end

  def speak(n)
    @message = n
  end
  
  attr_accessor :message
end

include Gimite

reudy = Reudy.new("public")
lingr = Lingr.new
reudy.client = lingr

post '/' do
  content_type :text
  data = JSON.parse(params[:json])
#  puts "nick: #{data["events"][0]["message"]["nickname"]} text: #{data["events"][0]["message"]["text"]}"
  reudy.onOtherSpeak(data["events"][0]["message"]["nickname"],data["events"][0]["message"]["text"])
  return lingr.message
end
