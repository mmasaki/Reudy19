#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

#文尾だけを使った類似判定。
$REUDY_DIR= "." unless defined?($REUDY_DIR)

require 'set'
require $REUDY_DIR+'/reudy_common'
require $REUDY_DIR+'/message_log'

module Gimite
  #類似発言検索器。
  class SimilarSearcher  
=begin
    文尾@compLen文字が1文字違いの発言を類似発言とする。
    ただし、ひらがなと一部の記号のみが対象。
    @tailMapは、「文尾@compLen文字と、そこから任意の1文字を抜いた物」をキーとし、
    発言番号の配列を値とする。
    例えば、10行目が「答えが分かりませんでした。」という発言なら、
      @tailMap["ませんでした"].include?(10)
      @tailMap["せんでした"].include?(10)
      @tailMap["まんでした"].include?(10)
      @tailMap["ませでした"].include?(10)
      @tailMap["ませんした"].include?(10)
      @tailMap["ませんでた"].include?(10)
      @tailMap["ませんでし"].include?(10)
    は全てtrueになる。これを使って「文尾が同じor1文字違いの発言」を探す。
=end
    include Gimite
    
    def initialize(fileName, log, db)
      require "#{$REUDY_DIR}/#{db}"
      @log = log
      @log.addObserver(self)
      @compLen = 6 #比較対象の文尾の長さ
      makeDictionary(fileName)
    end
    
    #inputに類似する各発言に対して、発言番号を引数にblockを呼ぶ。発言の順序は微妙にランダム。
    def eachSimilarMsg(input, &block)
      ws = normalizeMsg(input)
      return if ws.size <= 1
      if ws.size >= @compLen
        wtail = ws[-@compLen..-1] #文尾。
        randomEach(@tailMap[wtail], &block)
        0.upto(@compLen.pred) do |i|
          randomEach(@tailMap[wtail[0...i] + wtail[i+1..-1] ], &block) #途中を1文字抜かしたもの。
        end
      else
        randomEach(@tailMap[ws], &block)
      end
    end
    
    #contの各要素について、ランダムな順序でblockを呼び出す。
    def randomEach(cont)
      if cont
        cont.shuffle.each do |c|
          yield(c)
        end
      end
    end
    
    #発言が追加された。
    def onAddMsg
      recordTail(-1)
    end
    
    #ログがクリアされた。
    def onClearLog
      @tailMap.clear
    end
    
    #文尾辞書（@tailMap）を生成。
    def makeDictionary(fileName)
      begin
        @tailMap = DB.new(fileName)
      rescue LoadError => ex
        warn ex.message
        warn "警告: 指定されたデータベースを利用できません。辞書を連想配列として保持する為、メモリを大量に消費します。"
        @tailMap = {}
      end
      if @tailMap.empty?
        warn "文尾辞書( #{fileName})を作成中..."
        0.upto(@log.size.pred) do |i|
          warn "#{i+1}行目..." if ((i+1) % 1000).zero?
          recordTail(i)
        end
      end
    end
    
    #lineN番の発言の文尾を記録。
    def recordTail(line_n)
      ws = normalizeMsg(@log[line_n].body)
      return nil if ws.size <= 1
      if ws.size >= @compLen
        wtail = ws[-@compLen..-1] #文尾。
        addToTailMap(wtail, line_n)
        0.upto(@compLen.pred) do |i|
          addToTailMap(wtail[0...i]+wtail[i+1..-1], line_n) #途中を1文字抜かしたもの。
        end
      else
        addToTailMap(ws, line_n)
      end
    end
    
    #@tailMapに追加。
    def addToTailMap(tail, line_n)
      line_n += @log.size if line_n < 0
      return if line_n < 0
      if @tailMap[tail]
        @tailMap[tail] += [line_n]
      else
        @tailMap[tail] = [line_n]
      end
    end
    
    #発言から「ひらがなと一部の記号」以外を消し、記号を統一する。
    def normalizeMsg(s)
      s = s.gsub(/[^ぁ-んー−？！\?!\.]+/, "")
      s.gsub!(/？/, "?")
      s.gsub!(/！/,"!")
      s.gsub!(/[ー−+]/, "ー")
      s
    end
  end
  
  if __FILE__ == $PROGRAM_NAME
    dir = ARGV[0]
    log = MessageLog.new(dir + "/log.dat")
    sim = SimilarSearcher.new(dir + "/db", log)
    sim.eachSimilarMsg(ARGV[1]) do |mid|
      printf("[%d] %s\n", mid, log[mid].body)
    end
  end
end
