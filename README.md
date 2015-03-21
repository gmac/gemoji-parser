# gemoji-parser

The missing helper methods for [GitHub's Gemoji](https://github.com/github/gemoji) gem. This utility provides a parsing API for the `Emoji` corelib (provided by Gemoji). The parser includes quick tokenizers for transforming unicode symbols (🐠) into token symbols (`:tropical_fish:`), and arbitrary block replacement methods for custom formatting of symbols.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gemoji-parser'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install gemoji-parser

To run tests:

	$ bundle exec rake spec

## Usage


### Tokenizing

These methods perform basic conversions of unicode symbols to token symbols, and vice versa.

```ruby
EmojiParser.tokenize("Test 🙈 🙊 🙉")
# "Test :see_no_evil: :speak_no_evil: :hear_no_evil:"

EmojiParser.detokenize("Test :see_no_evil: :speak_no_evil: :hear_no_evil:")
# "Test 🙈 🙊 🙉"
```

### Block Parsing

For custom symbol transformations, use the block parser methods. All parsers yeild Gemoji [Emoji::Character](https://github.com/github/gemoji/blob/master/lib/emoji/character.rb) instances into the parsing block for custom formatting.

**Unicode symbols**

```ruby
EmojiParser.parse_unicode('Test 🐠') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end

# 'Test <img src="unicode/1f420.png" alt=":tropical_fish:">'
```

**Token symbols**

```ruby
EmojiParser.parse_tokens('Test :tropical_fish:') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end

# 'Test <img src="unicode/1f420.png" alt=":tropical_fish:">'
```

**Emoticon symbols**

```ruby
EmojiParser.parse_emoticons('Test ;-)') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end

# 'Test <img src="unicode/1f609.png" alt=":wink:">'
```

**Parsing all symbol types**

If you want to parse multiple symbol formats in a single pass, then use the `parse` method. This has the advantage of allowing parsed symbols to be re-inserted into the text without getting re-parsed by subsequent passes (ex: a unicode symbol parsed into an image tag may safely use its token as the image alt text).

```ruby
EmojiParser.parse('🐠 :tropical_fish: ;-)') { |emoji| emoji.hex_inspect }

# '1f420 1f420 1f609'
```

The `parse` method also accepts options specifying which symbol types to parse:

```ruby
EmojiParser.parse('🐠 :tropical_fish: ;-)', unicode: true, tokens: true) do |emoji|
  emoji.hex_inspect
end

# 'Test 1f420 1f420 ;-)'
```

Note that the discrete parsing methods for each symbol type are smaller and simpler than the `parse` macro method. If you don't need to hit multiple symbol types in a single pass, then favor the discrete methods.

### Lookups & File Paths

To quickly locate `Emoji::Character` instances using any symbol format (unicode, token, emoticon), use the `find` method:

```
EmojiHelper.find(🐠)
EmojiHelper.find('tropical_fish')
EmojiHelper.find(';-)')
```

To quickly access the filepath for any symbol format, use the `filepath` method. You may optionally provide a filepath that overrides the Gemoji default (this may be useful if you'd like to upload your images to CDN, and simply reference them from there):

```ruby
EmojiHelper.find('tropical_fish')
# "unicode/1f420.png"

EmojiParser.filepath('tropical_fish', '//cdn.fu/emoji/')
# "//cdn.fu/emoji/1f420.png"
```

## Shoutout

Thanks to the GitHub team for the [Gemoji](https://github.com/github/gemoji) gem. They're handling all the heavy lifting here.

## Contributing

1. Fork it ( https://github.com/gmac/gemoji-parser/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
