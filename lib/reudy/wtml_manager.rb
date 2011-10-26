#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

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
      msgN = @log.size - 1
      @wordSearcher.searchWords(@log[msgN].body).each do |word|
        word.mids.push(msgN)
      end
    end
    
    def onClearLog
      @wordSet.words.each do |word|
        word.mids.clear
      end
    end
    
    #単語wordにmidsを付ける。
    def attachMsgList(word)
      word.mids = []
      @log.each_with_index do |log, i|
        word.mids.push(i) if @wordSearcher.hasWord(log.body, word)
      end
    end
  end
end
