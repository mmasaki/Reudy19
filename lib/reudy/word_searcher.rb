#ncoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require $REUDY_DIR+'/wordset'

module Gimite

#文中から既知の単語を探す
class WordSearcher
  include(Gimite)
  
  def initialize(wordSet)
    @wordSet = wordSet
  end
  
  #文章がその単語を含んでいるか
  def hasWord(sentence, word)
    return false if !sentence.include?(word.str) || !(sentence =~ Regexp.new("(.|^)" + Regexp.escape(word.str) + "(.|$)"))
    preChar = $1
    folChar = $2
    wordAr = word.str.split(//)
    #カタカナ列や英文字列を途中で切るような単語は不可
    return false if (preChar+wordAr[0]) =~ /[ァ-ンー−][ァ-ンー−]/o || (preChar+wordAr[0]) =~ /[a-zA-Z][a-zA-Z]/o\
                || (wordAr[-1]+folChar) =~ /[ァ-ンー−][ァ-ンー−]/o || (wordAr[-1]+folChar) =~ /[a-zA-Z][a-zA-Z]/o
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
