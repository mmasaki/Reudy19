#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

$REUDY_DIR= "./lib/reudy" unless defined?($REUDY_DIR)

require 'optparse'
require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'

module Gimite
  STDOUT.sync = true
  STDERR.sync = true
  Thread.abort_on_exception = true
  
  opt = OptionParser.new
  
  directory = 'public'
  opt.on('-d DIRECTORY') { |v| directory = v; p v }
  
  db = 'pstore'
  opt.on('--db DB_TYPE') { |v| db = v }
  
  mecab = nil
  opt.on('-m','--mecab') { |v| mecab = true }
  
  opt.parse!(ARGV)
  directory = ARGV.first unless ARGV.empty?
  
  begin
    #IRC用ロイディを作成
    client= BotIRCClient.new(Reudy.new(directory,{},db,mecab))
    client.processLoop
  rescue Interrupt
    #割り込み発生。
  end
end
