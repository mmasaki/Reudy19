#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

#文尾だけを使った類似判定。
require $REUDY_DIR+'/reudy_common'

module Gimite
  #注目判定器。
  class AttentionDecider
    include Gimite
    
    def initialize
      @lastNick = nil #最後の発言者。"!"なら、自分。
      @prob = 1.0
      @recentSpeakers = Array.new(10) #nilで初期化されている
    end
    
    #パラメータを設定する。
    def setParameter(probs)
      @minProb = probs[:min] #発言率の最低値。
      @maxProb = probs[:max] #発言率の最高値。
      @probs = probs[:default] #デフォルトの発言率。
      @calledProb = probs[:called] #名前を呼ばれた時の発言率の下限。
      @selfProb = probs[:self] #普段の自己発言の発言率。
      @ignoredProb = probs[:ignored] #無視された後の自己発言の発言率。
      @probRange = @maxProb - @minProb
    end
    
    #他人が発言した時にこれを呼ぶ。
    #発言率を返す。
    def onOtherSpeak(from_nick, sentence, called)
      updateRecentSpeakers(from_nick)
  
      #今回の発言率を求める。
      if called || recentOtherSpeakers.size == 1
        prob = @calledProb
      else
        prob = @prob
      end
      
      #発言率を更新。
      if called
        raiseProbability(1.0) #呼ばれたら、発言率を最高に。
      else
        raiseProbability(-0.2) #それ以外のケースでは、発言率は徐々に下がる。
      end
      
      prob
    end
    
    #自分が発言した時にこれを呼ぶ。
    def onSelfSpeak(usedWords)
      updateRecentSpeakers("!")
    end
    
    #沈黙がしばらく続いた時にこれを呼ぶ。発言率を返す。
    def onSilent
      updateRecentSpeakers(nil)
      puts self
      if @lastNick == "!"
        raiseProbability(-0.2)
        @ignoredProb
      elsif recentOtherSpeakers.size == 1
        @calledProb
      else
        @selfProb
      end
    end
    
    #現在の状態を表す文字列。
    def to_s
      "デフォルト発言率:%.2f, 最近の発言者: #{@recentSpeakers}" % @prob
    end
    
    private
    
    #発言率を上げ下げする。
    #上げ率rateは、発言率の変動範囲(@probRange)に対する割合で指定する。
    def raiseProbability(rate)
      @prob = [[@prob+rate*@probRange, @maxProb].min, @minProb].max
    end
    
    def updateRecentSpeakers(nick)
      @lastNick = nick if nick
      @recentSpeakers.shift
      @recentSpeakers.push(nick)
    end
    
    def recentOtherSpeakers
      t = @recentSpeakers - [nil, "!"]
      t.uniq!
      t
    end
  end
end
