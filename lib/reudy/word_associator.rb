#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

module Gimite
  #単語連想器
  class WordAssociator  
    def initialize(file_name)
      @file_name = file_name
      @assoc_word_map = {}
      loadFromFile
    end
    
    def loadFromFile
      if File.exists?(@file_name)
        File.open(@file_name) do |file|
          file.each_line do |line|
            line.chomp!
            strs = line.split(/\t/)
            @assoc_word_map[strs.first] = strs[1..-1] if strs.size >= 2
          end
        end
      end
    end
    
    #1単語から連想された1単語を返す
    def associate(word_str)
      if strs = @assoc_word_map[word_str]
        strs.sample
      else
        nil
      end
    end
    
    #1単語から連想された全ての単語を返す
    def associateAll(word_str)
      @assoc_word_map[word_str]
    end  
  end
end
