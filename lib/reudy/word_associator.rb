#encoding:utf-8
#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

module Gimite

#単語連想器
class WordAssociator  
  def initialize(fileName)
    @fileName = fileName
    loadFromFile
  end
  
  def loadFromFile
    @assocWordMap = {}
    return unless File.exists?(@fileName)
    open(@fileName) do |file|
      file.each_line do |line|
        line.chomp!
        strs = line.split(/\t/)
        if strs.size >= 2
          @assocWordMap[strs[0]] = strs[1..-1]
        end
      end
    end
  end
  
  #1単語から連想された1単語を返す
  def associate(wordStr)
    strs = @assocWordMap[wordStr]
    size = strs.size
    return strs[rand(size)] if strs && size.nonzero?
    return nil
  end
  
  #1単語から連想された全ての単語を返す
  def associateAll(wordStr)
    return @assocWordMap[wordStr]
  end  
end

end #module Gimite
