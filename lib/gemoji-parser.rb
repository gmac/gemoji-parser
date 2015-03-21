require 'gemoji-parser/version'
require 'gemoji'

module EmojiParser
  extend self

  # Emoticons
  # ---------
  # The base emoticons set (below) is generated with "noseless" variants, ie:  :-) and :)
  # The generated `EmojiParser.emoticons` hash is formatted as:
  # ---
  # > {
  # >   ":-)" => :blush,
  # >   ":)" => :blush,
  # >   ":-D" => :smile,
  # >   ":D" => :smile,
  # > }
  # 
  # This base set is selected for commonality and high degrees of author intention.
  # If you want more/different emoticons:
  # - Please DO customize the `EmojiParser.emoticons` hash in your app runtime.
  # - Please DO NOT customize this source code and issue a pull request.
  #
  # To add an emoticon:
  # ---
  # > EmojiParser.emoticons[':-$'] = :grimacing
  # > EmojiParser.rehash!
  # 
  # To remove an emoticon:
  # ---
  # > EmojiParser.emoticons.delete(':-$')
  # > EmojiParser.rehash!
  # 
  # NOTE: call `rehash!` after making changes to Emoji/emoticon sets.
  # Rehashing updates the parser's regex cache with the latest icons.
  #
  def emoticons
    return @emoticons if defined? @emoticons
    @emoticons = {}
    emoticons = {
      angry: ">:-(",
      blush: ":-)",
      cry: ":'(",
      confused: [":-\\", ":-/"],
      disappointed: ":-(",
      kiss: ":-*",
      neutral_face: ":-|",
      monkey_face: ":o)",
      open_mouth: ":-o",
      smiley: "=-)",
      smile: ":-D",
      stuck_out_tongue: [":-p", ":-P", ":-b"],
      stuck_out_tongue_winking_eye: [";-p", ";-P", ";-b"],
      wink: ";-)"
    }

    # Parse all named patterns into a flat hash table,
    # where pattern is the key and its token is the value.
    # all patterns are duplicated with the "noseless" variants, ie:  :-) and :)
    emoticons.each_pair do |name, patterns|
      patterns = [patterns] unless patterns.is_a?(Array)
      patterns.each do |pattern| 
        @emoticons[pattern] = name
        @emoticons[pattern.sub(/(?<=:|;|=)-/, '')] = name
      end
    end

    @emoticons
  end

  attr_writer :emoticons

  # Rehashes all cached regular expressions.
  # IMPORTANT: call this once after changing emoji characters or emoticon patterns.
  def rehash!
    unicode_regex(rehash: true)
    token_regex(rehash: true)
    emoticon_regex(rehash: true)
  end

  # DEPRECATED, TODO: remove in v1.2.x
  # - Options: rehash:boolean
  def emoji_regex(opts={})
    puts 'EmojiParser: #emoji_regex is deprecated. Please use #unicode_regex.'
    unicode_regex(opts)
  end

  # Creates an optimized regular expression for matching unicode symbols.
  # - Options: rehash:boolean
  def unicode_regex(opts={})
    return @unicode_regex if defined?(@unicode_regex) && !opts[:rehash]
    pattern = []

    Emoji.all.each do |emoji|
      u = emoji.unicode_aliases.map do |str|
        str.codepoints.map { |c| '\u{%s}' % c.to_s(16).rjust(4, '0') }.join('')
      end
      # Simple method: x10 slower!
      # pattern.concat u.sort! { |a, b| b.length - a.length }
      pattern << unicode_matcher(u) if u.any?
    end

    @unicode_pattern = pattern.join('|')
    @unicode_regex = Regexp.new("(#{@unicode_pattern})")
  end

  # Creates a regular expression for matching token symbols.
  # - Options: rehash:boolean (currently unused)
  def token_regex(opts={})
    return @token_regex if defined?(@token_regex)
    @token_pattern = ':([\w+-]+):'
    @token_regex = Regexp.new(@token_pattern)
  end

  # Creates an optimized regular expression for matching emoticon symbols.
  # - Options: rehash:boolean
  def emoticon_regex(opts={})
    return @emoticon_regex if defined?(@emoticon_regex) && !opts[:rehash]
    pattern = {}

    emoticons.keys.each do |icon|
      compact_icon = icon.gsub('-', '')

      # Check to see if this icon has a compact version, ex:  :-)  versus  :)
      # One expression will match as many nose/noseless variants as possible.
      if compact_icon != icon && emoticons[compact_icon]
        compact_regex = Regexp.escape(icon).gsub('-', '-?')

        # Keep this expression if it hasn't been defined yet,
        # or if it's longer than a previously defined pattern.
        if !pattern[compact_icon] || pattern[compact_icon].length < compact_regex.length
          pattern[compact_icon] = compact_regex
        end
      elsif !pattern[icon]
        pattern[icon] = Regexp.escape(icon)
      end
    end

    @emoticon_pattern = "(?<=^|\\s)(?:#{ pattern.values.join('|') })(?=\\s|$)"
    @emoticon_regex = Regexp.new("(#{@emoticon_pattern})")
  end

  # Generates a macro regex for matching one or more symbol sets.
  # Regex uses various formats, based on symbol sets. Yields match as $1 OR $2
  # T/EU:        (token-$1)|(emoticon-unicode-$2)
  # T/E or T/U:  (token-$1)|(emoticon/unicode-$2)
  # EU:          (emoticon/unicode-$1)
  # - Options: unicode:boolean, tokens:boolean, emoticons:boolean
  def macro_regex(opts={})
    unicode_regex if opts[:unicode]
    token_regex if opts[:tokens]
    emoticon_regex if opts[:emoticons]
    pattern = []

    if opts[:emoticons] && opts[:unicode]
      pattern << "(?:#{ @emoticon_pattern })"
      pattern << @unicode_pattern
    else
      pattern << @emoticon_pattern if opts[:emoticons]
      pattern << @unicode_pattern if opts[:unicode]
    end

    pattern = pattern.any? ? "(#{ pattern.join('|') })" : ""

    if opts[:tokens]
      if pattern.empty?
        pattern = @token_pattern
      else
        pattern = "(?:#{ @token_pattern })|#{ pattern }"
      end
    end

    Regexp.new(pattern)
  end

  # Parses all unicode symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_unicode(text)
    text.gsub(unicode_regex) do |match|
      emoji = Emoji.find_by_unicode($1)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all token symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_tokens(text)
    text.gsub(token_regex) do |match|
      emoji = Emoji.find_by_alias($1)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Parses all emoticon symbols within a string.
  # - Block: performs all symbol transformations.
  def parse_emoticons(text)
    text.gsub(emoticon_regex) do |match|
      if emoticons.has_key?($1)
        emoji = Emoji.find_by_alias(emoticons[$1].to_s)
        block_given? && emoji ? yield(emoji) : match
      else
        match
      end
    end
  end

  # DEPRECATED, TODO: remove in v1.2.x
  def parse_all(text)
    puts 'EmojiParser: #parse_all is deprecated. Please use #parse.'
    parse(text, emoticons: false)
  end

  # Parses all emoji unicode, tokens, and emoticons within a string.
  # - Block: performs all symbol transformations.
  # - Options: unicode:boolean, tokens:boolean, emoticons:boolean
  def parse(text, opts={})
    opts = { unicode: true, tokens: true, emoticons: true }.merge(opts)
    if opts.one?
      return parse_unicode(text)   { |e| yield e } if opts[:unicode]
      return parse_tokens(text)    { |e| yield e } if opts[:tokens]
      return parse_emoticons(text) { |e| yield e } if opts[:emoticons]
    end
    text.gsub(macro_regex(opts)) do |match|
      a = defined?($1) ? $1 : nil
      b = defined?($2) ? $2 : nil
      emoji = find(a || b)
      block_given? && emoji ? yield(emoji) : match
    end
  end

  # Transforms all unicode emoji into token strings.
  def tokenize(text)
    parse_unicode(text) { |emoji| ":#{emoji.name}:" }
  end

  # Transforms all token strings into unicode emoji.
  def detokenize(text)
    parse_tokens(text) { |emoji| emoji.raw }
  end

  # Finds an Emoji::Character instance for an unknown symbol type.
  # - symbol: an <Emoji::Character>, or a unicode/token/emoticon string.
  def find(symbol)
    return symbol if (symbol.is_a?(Emoji::Character))
    symbol = emoticons[symbol].to_s if emoticons.has_key?(symbol)
    Emoji.find_by_alias(symbol) || Emoji.find_by_unicode(symbol) || nil
  end

  # Gets the file reference for a symbol; optionally with a custom path.
  # - symbol: an <Emoji::Character>, or a unicode/token/emoticon string.
  # - path: a file path to sub into symbol's filename.
  def filepath(symbol, path=nil)
    emoji = find(symbol)
    return nil unless emoji
    return emoji.image_filename unless path
    "#{ path.sub(/\/$/, '') }/#{ emoji.image_filename.split('/').pop }"
  end

  private

  # Compiles an optimized unicode pattern for fast matching.
  # Matchers use as small a base as possible, with added options. Ex:
  # 1-char base \w option:  \u{1f6a9}\u{fe0f}?
  # 2-char base \w option:  \u{1f1ef}\u{1f1f5}\u{fe0f}?
  # 1-char base \w options: \u{0031}(?:\u{fe0f}\u{20e3}|\u{20e3}\u{fe0f})?
  def unicode_matcher(patterns)
    return patterns.first if patterns.length == 1

    # Sort patterns, longest to shortest:
    patterns.sort! { |a, b| b.length - a.length }

    # Select a base pattern:
    # this is the shortest prefix contained by all patterns.
    base = patterns.last

    if patterns.all? { |p| p.start_with?(base) }
      base = patterns.pop
    else
      base = base.match(/\\u\{.+?\}/).to_s
      base = nil unless patterns.all? { |p| p.start_with?(base) }
    end

    # Collect base options and/or alternate patterns:
    opts = []
    alts = []
    patterns.each do |pattern|
      if base && pattern.start_with?(base)
        opts << pattern.sub(base, '')
      else
        alts << pattern
      end
    end

    # Format base options:
    if opts.length == 1
      base += "#{ opts.first }?"
    elsif opts.length > 1
      base += "(?:#{ opts.join('|') })?"
    end

    alts << base if base
    alts.join('|')
  end
end