#encoding: utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント

$OUT_KCODE= "UTF8" #出力文字コード
$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR) #スクリプトがあるディレクトリ

require 'optparse'
require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'

module Gimite

trap(:INT){
  exit
}

$stdout.sync = true
$stderr.sync = true
Thread.abort_on_exception = true

opt = OptionParser.new

directory = 'public'
opt.on('-d DIRECTORY') do |v|
  directory = v
end

db = 'pstore'
opt.on('-db DB_TYPE') do |v|
  db = v
end
opt.parse!(ARGV)

MessageLog.enable_update_check = !$OPT_f

begin
  #IRC用ロイディを作成
  client= BotIRCClient.new(Reudy.new(directory,{},db))
  client.processLoop()
rescue Interrupt
  #割り込み発生。
end
end #module Gimite
