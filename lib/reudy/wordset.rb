#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

require "fileutils"
require $REUDY_DIR+'/reudy_common'

module Gimite
class Word #単語クラス
  def initialize(s, a = "", m = [])
    @str = s #単語の文字列。
    @author = a #単語を教えた人。
    @mids = m #この単語を含む発言の番号。
  end

  attr_accessor :str,:author,:mids
  
  def ==(other)
    return @str == other.str
  end
  
  def eql?(other)
    return @str == other.str
  end
  
  def hash
    return @str.hash
  end
  
  def <=>(other)
    return @str <=> other.str
  end
  
  def inspect
    return "<Word: \"#{str}\">"
  end
end

# 単語集
class WordSet
  include Gimite, Enumerable
  
  def initialize(innerFileName)
    @innerFileName = innerFileName
    @addedWords = []
    if File.exist?(@innerFileName)
      File.open(@innerFileName) do |f|
        @words = YAML.load(f)
      end
    end
    @words = [] unless @words
  end

  attr_reader :words
  
  #単語を追加
  def addWord(str, author = "")
    added_word = Word.new(str, author)
    @words.each_with_index do |word,i|
      if str.include?(word.str)
        if word && word.str == str
          return nil
        else
          @words[i, 0] = [added_word]
          @addedWords << added_word
          return added_word
        end
      end
    end
  end
  
  #ファイルに保存
  def save
    File.open(@innerFileName, "w") do |f|
      YAML.dump(@words, f)
    end
  end
  
  #単語イテレータ
  def each
    @words.each do |word|
      yield(word)
    end
  end
  
  #中身をテキスト形式で出力。
  def output(io)
    @words.each do |word|
      io.puts "#{word.str}\t#{word.author}\t#{word.mids.join(",")}"
    end
  end
  
  private
  
  #既存のファイルとかぶらないファイル名を作る。
  def makeNewFileName(base)
    return base unless File.exist?(base)
    i = 2
    loop do
      return name unless File.exist?(base+i.to_s)
      i += 1
    end
  end
end

end #module Gimite
