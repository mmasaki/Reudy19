#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require "rubygems"
require 'socket'
require 'thread'
require 'kconv'
require 'jcode'
require 'timeout'
require "webrick"
require "cgi"
require "json"
require $REUDY_DIR+'/reudy_common'


module Gimite


#ボット用のLingrクライアント
class BotLingr2Client
  
  include(Gimite)
  
  def initialize(user)
    @user= user
    @port= @user.settings("port").to_i()
    @nick= @user.settings("nick")
    @user.client= self
    @user.onBeginConnecting()
    @speech_que = []
  end
  
  #メッセージをひたすら処理するループ。
  def processLoop()
    @server = WEBrick::HTTPServer.new(:Port => @port)
    @server.mount_proc("/") do |req, res|
      (key, value) =
        req.body.split(/&/).map(){ |s| s.split(/=/) }.find(){ |k, v| k == "json" }
      jputs CGI.unescape(value).toeuc()
      input = JSON.parse(CGI.unescape(value).toeuc())
      for event in input["events"]
        if event["message"]
          nick = event["message"]["nickname"]
          text = event["message"]["text"]
          jputs [nick, text].join(": ")
          @user.onOtherSpeak(nick, text, false)
        end
      end
      res["Content-Type"]= "text/plain"
      jputs "出力: " + @speech_que.join("\n")
      res.body = @speech_que.join("\n").toutf8()
      @speech_que = []
    end
    trap("INT"){ @server.shutdown() }
    @server.start()
  end
  
  #補助情報を出力
  def outputInfo(s)
  end
  
  #発言する
  def speak(s)
    jputs "発言: #{s}"
    @speech_que.push(s)
  end
  
  #チャンネルを移動。接続中はこっちを使う。
  def moveChannel(channel)
    raise("Not implemented")
  end
  
  #チャンネルを変更。切断中はこっちを使う。
  def setChannel(channel)
    raise("Not implemented")
  end
  
  def status=(status)
    #@main_room.set_nickname(@nick + (status ? "@#{status}" : ""))
  end
  
  #終了。
  def exit()
    @server.shutdown()
  end
  
  def on_init
    jputs '*** Initialized (CTRL-C to quit)'
    @user.onSelfJoin()
  end

end


end #module Gimite
