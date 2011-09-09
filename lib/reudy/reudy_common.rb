#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

module Gimite
  #デバッグ出力
  def dprint(caption, *objs)
    objs.map!{|obj| obj.inspect }
    warn("caption : #{objs.join("/")}")
  end
  
  #contの全ての要素に対してpredが真を返すか。
  def for_all?(cont, &pred)
    cont.all?{|item| pred.call(item) }
  end
  
  #contの中にpredが真を返す要素が存在するか。
  def there_exists?(cont, &pred)
    cont.any?{|item| pred.call(item) }
  end
  
  def sigma(range, &block)
    sum = nil
    range.each do |v|
      sum = sum ? (sum+block.call(v)) : block.call(v)
    end
    return sum
  end
  
  module_function(:dprint, :for_all?, :there_exists?, :sigma)
end
