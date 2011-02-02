#ncoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require $REUDY_DIR+'/wordset'

KATAKANA = Regexp.compile("[ァ-ンー−][ァ-ンー−]") #カタカナ
ALPHA_NUMERIC =  Regexp.compile("[a-zA-Z][a-zA-Z]") #英数

module Gimite

#文中から既知の単語を探す
class WordSearcher
  include Gimite
  
  def initialize(wordSet)
    @wordSet = wordSet
  end
  
  #文章がその単語を含んでいるか
  def hasWord(sentence, word)
    return false if !sentence.include?(word.str) || !(sentence =~ Regexp.new("(.|^)" + Regexp.escape(word.str) + "(.|$)"))
    preChar = $1
    folChar = $2
    wordAr = word.str
    #カタカナ列や英文字列を途中で切るような単語は不可
    return false if (preChar+wordAr[0]) =~ KATAKANA || (preChar+wordAr[0]) =~ ALPHA_NUMERIC\
                || (wordAr[-1]+folChar) =~ KATAKANA || (wordAr[-1]+folChar) =~ ALPHA_NUMERIC
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
