#ncoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require $REUDY_DIR+'/wordset'

KANA_AN = Regexp.compile("[ァ-ンー−][ァ-ンー−]|[a-zA-Z][a-zA-Z]") #カタカナか英数

module Gimite

#文中から既知の単語を探す
class WordSearcher
  include Gimite
  
  def initialize(wordSet)
    @wordSet = wordSet
  end
  
  #文章がその単語を含んでいるか
  def hasWord(sentence, word)
    return false if !sentence.include?(word.str) || !sentence =~ /(.|^)#{Regexp.escape(word.str)}(.|$)/
    return false if ($1.to_s+word.str[0]) =~ KANA_AN || (word.str[-1]+$2.to_s) =~ KANA_AN #カタカナ列や英文字列を途中で切るような単語は不可
    return true
  end
  
  #文中から既知の単語を探す
  def searchWords(sentence)
    words = []
    @wordSet.each do |word|
      if hasWord(sentence, word)
        sentence = sentence.gsub(Regexp.new(Regexp.escape(word.str)), " ")
        words.push(word)
      end
    end
    return words
  end
end

end #module Gimite
