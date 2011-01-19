#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント

$OUT_KCODE= "UTF-8" #出力文字コード
$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR) #スクリプトがあるディレクトリ

trap(:INT){ exit }

require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'
require $REUDY_DIR+'/reudy_common'

module Gimite

class StdioClient
  
  include(Gimite)
  
  def initialize(user, yourNick)
    @user = user
    @user.client = self
    @yourNick = yourNick
    greeting = @user.settings("joining_message")
    puts greeting if greeting
  end
  
  def loop
    $stdin.each_line do |line|
#      $stderr.print("> "+line)#仮
      line = line.chomp
      if line.empty?
        @user.onSilent
      elsif @yourNick
        @user.onOtherSpeak(@yourNick, line)
      elsif line =~ /^(.+?) (.*)$/
        @user.onOtherSpeak($1, $2)
      else
        $stderr.print("Error\n")
      end
    end
  end
  
  #補助情報を出力
  def outputInfo(s)
    puts "(#{s})"
  end
  
  #発言する
  def speak(s)
    puts s
  end
  
  #終了する
  def exit
    Kernel.exit(0)
  end
  
end


$stdout.sync = true
if ARGV.size == 1 || ARGV.size == 2
  #標準入出力用ロイディを作成
  client = StdioClient.new(Reudy.new(ARGV[0]), ARGV[1] && ARGV[1])
  client.loop
else
  $stderr.print("Usage: ruby stdio_reudy.rb ident_dir your_name\n\n 'ident_dir' is a directory which contains setting.txt, log.txt, etc.\n")
end


end #module Gimite
