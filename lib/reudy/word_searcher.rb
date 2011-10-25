#ncoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

require $REUDY_DIR+'/wordset'

KANA_AN = Regexp.compile("([ァ-ンー−][ァ-ンー−]|[a-zA-Z][a-zA-Z])") # #カタカナ又は英数

module Gimite
  #文中から既知の単語を探す
  class WordSearcher
    include Gimite
    
    def initialize(wordSet)
      @wordSet = wordSet
    end
    
    #文章がその単語を含んでいるか
    def hasWord(sentence, word)
      return false unless sentence.include?(word.str) 
      return false unless sentence =~ /(.|^)#{Regexp.escape(word.str)}(.|$)/
      return false if ("#{$1}#{word.str[0]}") =~ KANA_AN || ("#{word.str[-1]}#{$2}") =~ KANA_AN #カタカナ列や英文字列を途中で切るような単語は不可
      return true
    end
    
    #文中から既知の単語を探す
    def searchWords(sentence)
      @wordSet.words.select{|word| hasWord(sentence, word) }
    end
  end
end
