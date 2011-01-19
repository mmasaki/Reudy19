#encoding: utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント

$OUT_KCODE= "UTF8" #出力文字コード
$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR) #スクリプトがあるディレクトリ

require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'


module Gimite


$stdout.sync = true
$stderr.sync = true
Thread.abort_on_exception = true

if ARGV.size != 1 && ARGV.size != 2
  puts( "Usage: ruby irc_reudy.rb [-f] ident_dir\n\n'ident_dir' is a directory which contains setting.txt, log.txt, etc.")
  exit(1)
end

MessageLog.enable_update_check = !$OPT_f

begin
  #IRC用ロイディを作成
  client= BotIRCClient.new(Reudy.new(ARGV[0],{},ARGV[1]))
  client.processLoop()
rescue Interrupt
  #割り込み発生。
end


end #module Gimite
