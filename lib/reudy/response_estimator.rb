#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

$REUDY_DIR= "." unless defined?($REUDY_DIR)

require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/reudy_common'

module Gimite
  #指定の発言への返事を推定する。
  class ResponseEstimator  
    include Gimite
    
    def initialize(log, wordSearcher, msgFilter = proc{ |n| true }, wordFilter = proc{ |w| true })
      @cacheLimit = 40
      @log = log
      @wordSearcher = wordSearcher
      @msgFilter = msgFilter
      @wordFilter = wordFilter
      @cache = {}
    end
    
    #mid番目の発言への返事（と思われる発言）について、[発言番号,返事らしさ]を返す。
    #ただし、@msgFilter.call(返事の番号)を満たすのが条件。
    #該当するものが無ければ[nil,0]を返す。
    #debugが真なら、デバッグ出力をする。
    def responseTo(mid, debug = false)
      return [nil, 0] unless mid
      mid += @log.size if mid < 0
      return @cache[mid] if @cache[mid] && @msgFilter.call(@cache[mid].first) #キャッシュにヒット。

      numTargets = 5
      candMids = (mid+1..mid+numTargets).select{ |n| @msgFilter.call(n) }
      return [nil, 0] if candMids.empty?
      #この先の判定は重いので、先に「絶対nilになるケース」を除外。
      words = @wordSearcher.searchWords(@log[mid].body).select{ |w| @wordFilter.call(w) }
      resMid = nil
 
      #その発言からnumTargets行以内で、同じ単語を含むものが有れば、それを返事とみなす。
      #無ければ、直後の発言を返事とする。
      words.each do |word|
        word.mids.each do |n|
          if n > mid
            if n > mid + numTargets || (resMid && n >= resMid)
              break
            elsif candMids.include?(n)
              resMid = n
              break
            end
          end
        end
      end
      prob = resMid ? numTargets : 0 #同じ単語を含む方が、返事らしさが高い。
      resMid = candMids.first unless resMid
      prob += numTargets + 1 - (resMid-mid) #近い発言の方が、返事らしさが高い。
      
      #キャッシュしておく。
      @cache.clear if @cache.size >= @cacheLimit
      @cache[mid] = [resMid, prob]
     
      return [resMid, prob]
    end 
  end

  if __FILE__ == $PROGRAM_NAME 
    dir = ARGV[0]
    log = MessageLog.new(dir+"/log.dat")
    wordSet = WordSet.new(dir+"/words.dat")
    wordSearcher = WordSearcher.new(wordSet)
    resEst = ResponseEstimator.new(log, wordSearcher)
    ARGV[1..-1].map(&:to_i).each do |mid|
      printf("[%d]%s:\n", mid, log[mid].body)
      resMid, prob= resEst.responseTo(mid, true)
      printf("  [%d]%s (%d)\n", resMid, log[resMid].body, prob) if resMid
    end
  end
end

