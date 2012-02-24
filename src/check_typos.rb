
class CheckTypos
  attr_accessor :base_dir, :target_exts, :target_files

  def initialize(base_dir, target_exts, options = {})
    @base_dir = base_dir
    @target_exts = target_exts
    @verbose = options[:verbose]
    @threshold_second = options[:threshold_second] || 300 # 更新時間がこれ以前のものをupdate_fileと認める
    @permitted_word_file = options[:permitted_word_file] || 'permitted_words'

    @target_files = Dir["#{base_dir}/**/*.{#{target_exts.join(',')}}"]
    STDERR.puts "target file num: #{@target_files.length}" if @verbose

    pairs = getWeirdWordsWithoutPermittedWords
    new_permitted_pairs = confirm(pairs)
    updatePermitPairs(new_permitted_pairs) if 0 < new_permitted_pairs.length
  end

  # :force => trueとすると上書きする
  def createNewPermittedWordFile(options = {})
    raise "undefined" # TODO: 後で書く

    raise "permite file is exist so it can be created." if File.exist?(@permitted_word_file) && !options[:force]
    open(@permitted_word_file, "w") do |f|
    end
  end

  private

  #------------------------------------------------
  def getWeirdWordsWithoutPermittedWords
    result = (getWeirdPairs - getPermittedPairs).sort.uniq
    result.each{|w1, w2| STDERR.puts "weird_word_without_permit_word:\t#{w1} <-> #{w2}" if @verbose }
    result
  end

  def confirm(pairs)
    pairs.select do |w1, w2|
      print "#{w1} <-> #{w2} |\tpermit this pair? (y/n/q)"
      input = gets.strip
      exit if input == 'q'
      input == 'y'
    end
  end

  def updatePermitPairs(pairs)
    open(@permitted_word_file, "w") do |f|
      (@cache_permit_pairs + pairs).map{|w1, w2| [w1, w2].sort}.sort.uniq.each do |w1, w2|
        STDERR.puts "add permit pair:\t#{w1} <-> #{w2}" if @verbose
        f.puts "#{w1}:#{w2}"
      end
    end
  end

  # --------------------------------------------------------
  # TODO: あとでキャッシュ使用型に直す?
  def getAllWords
    getWordsOnUpdatedFiles
  end

  def getWordsOnUpdatedFiles(threshold_second=nil)
    words = []
    target_files.each do |path|
      STDERR.puts "searching: #{path}" if @verbose
      # threshold_secondが指定されていない場合は常にtrue
      if !threshold_second || ((Time.now - threshold_second) < File.mtime(path))
        STDERR.print (threshold_second ? "+" : "-") if @verbose
        words += File.read(path).scan(/[a-zA-Z][\w_]{3,}/) # 4文字以上で、かつ、先頭がアルファベットのもののみ対象
      end
    end
    words.sort.uniq.map{|w| w.downcase}
  end

  # wordsのなかでwordとの距離がdistance以下のワードがあればそれを返す
  # 無ければnilを返す
  def getNearestWord(word, words, distance)
    words.find{|w| (word != w) && !levenshteinDistanceIsLarge?(word, w, distance)}
  end

  # str1とstr2のlevenshtein距離がdistance以上か?
  def levenshteinDistanceIsLarge?(str1, str2, distance)
    distance < levenshteinDistance(str1, str2, distance+1)
  end

  # str1とstr2のlevenshtein距離を得る。
  # ただしupperが指定されており、かつlevenshtein距離がそれを超えるならupperが返される。
  def levenshteinDistance(str1, str2, upper = nil)
    return upper if upper && upper <= (str1.length - str2.length)

    # lenStr1 + 1 行 lenStr2 + 1 列のテーブル d を用意する
    hash = Hash.new

    len1 = str1.length
    len2 = str2.length

    (-1..len1-1).to_a.each { |i| hash[[ i, -1 ]] = i+1 }
    (-1..len2-1).to_a.each { |i| hash[[ -1, i ]] = i+1 }

    (0..len1-1).to_a.each do |i1|
      (0..len2-1).to_a.each do |i2|
        cost = (str1[i1] == str2[i2] || (str1[i1] =~ /\A[0-9]\Z/ && str2[i2] =~ /\A[0-9]\Z/) ) ? 0 : 2
        hash[[i1,i2]] = [ hash[[ i1 - 1, i2     ]] + 1,
                          hash[[ i1    , i2 - 1 ]] + 1,
                          hash[[ i1 - 1, i2 - 1 ]] + cost
                        ].min
      end
    end
    hash[[len1-1, len2-1]]
  end

  def getWeirdPairs
    all_words = getAllWords
    result = []
    recent_words = getWordsOnUpdatedFiles(@threshold_second)

    STDERR.puts "recent_words: #{recent_words.size}" if @verbose
    STDERR.puts "all_words: #{all_words.size}" if @verbose

    recent_words.each do |word|
      nw = getNearestWord(word, recent_words + all_words, 2)
      result << [word, nw].sort if nw
    end
    result.each{|w1, w2| STDERR.puts "weird_word: #{w1} <-> #{w2}" if @verbose}
    result
  end

  def getPermittedPairs
    unless @cache_permit_pairs
      if File.exist?(@permitted_word_file)
        @cache_permit_pairs = File.read(@permitted_word_file).scan(/^(\w+):(\w+)$/).map{|w1, w2| [w1, w2].sort}
      else
        open(@permitted_word_file, "w"){|f| } # ファイル作成
        @cache_permit_pairs = []
      end
    end
    @cache_permit_pairs
  end
end

if __FILE__ == $0
  CheckTypos.new(Dir.pwd, %w{rb}, :verbose => ENV['VERBOSE'])
end
