#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>
#Modified by Glass_saga <glass.saga@gmail.com>

module Gimite
  #デバッグ出力
  def dprint(caption, *objs)
    objs.map!(&:inspect)
    warn("#{caption}: #{objs.join("/")}")
  end
  
  #contの全ての要素に対してpredが真を返すか。
  def for_all?(cont)
    cont.all?{|item| yield(item) }
  end
  
  #contの中にpredが真を返す要素が存在するか。
  def there_exists?(cont)
    cont.any?{|item| yield(item) }
  end
  
  def sigma(range)
    sum = nil
    range.each do |v|
      sum = sum ? sum + yield(v) : yield(v)
    end
    sum
  end
  
  module_function(:dprint, :for_all?, :there_exists?, :sigma)
end
