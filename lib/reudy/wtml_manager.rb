#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/word_searcher'

module Gimite
#「単語→発言番号」リストを管理するもの。
class WordToMessageListManager
  def initialize(wordSet, log, wordSearcher)
    @wordSet = wordSet
    @log = log
    @wordSearcher = wordSearcher
    @log.addObserver(self)
  end
  
  def onAddMsg
    @wordSearcher.searchWords(@log[-2].body).each do |word|
      word.msgNs.push(msgN)
    end
  end
  
  def onClearLog
    @wordSet.each do |word|
      word.msgNs.clear
    end
  end
  
  #単語wordにmsgNsを付ける。
  def attachMsgList(word)
    word.msgNs = []
    @log.each_index do |i|
      word.msgNs.push(i) if @wordSearcher.hasWord(@log[i].body, word)
    end
  end
end
end #module Gimite
