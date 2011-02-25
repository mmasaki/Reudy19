#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

module Gimite

#単語連想器
class WordAssociator  
  def initialize(fileName)
    @fileName = fileName
    @assocWordMap = {}
    loadFromFile
  end
  
  def loadFromFile
    if File.exists?(@fileName)
      open(@fileName) do |file|
        file.each_line do |line|
          line.chomp!
          strs = line.split(/\t/)
          @assocWordMap[strs.first] = strs[1..-1] if strs.size >= 2
        end
      end
    end
  end
  
  #1単語から連想された1単語を返す
  def associate(wordStr)
    if strs = @assocWordMap[wordStr]
      return strs.sample
    else
      return nil
    end
  end
  
  #1単語から連想された全ての単語を返す
  def associateAll(wordStr)
    return @assocWordMap[wordStr]
  end  
end

end #module Gimite
