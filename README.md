# gemoji-parser

The missing helper methods for [GitHub's Gemoji](https://github.com/github/gemoji) gem. This utility provides a parsing API for the `Emoji` corelib (provided by Gemoji). The parser includes quick tokenizers for transforming unicode symbols (🐠) into token symbols (`:tropical_fish:`), and arbitrary block replacement methods for custom formatting of symbols.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gemoji-parser'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gemoji-parser

To run tests:

	$ be rake spec

## Usage


### Tokenizing

These methods perform basic conversions of unicode symbols to token symbols, and vice versa.

```
EmojiParser.tokenize("Test 🙈 🙊 🙉")
 # "Test :see_no_evil: :speak_no_evil: :hear_no_evil:"

EmojiParser.detokenize("Test :see_no_evil: :speak_no_evil: :hear_no_evil:")
 # "Test 🙈 🙊 🙉"
```

### Block Parsing

For custom symbol transformations, use the block parser methods. All parsers yeild Gemoji `Emoji::Character` instances into the parsing block for custom formatting.

**Unicode symbols**

```
EmojiParser.parse_unicode('Test 🐠') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end

 # 'Test <img src="unicode/1F420.png" alt=":tropical_fish:">'
```

**Token symbols**

```
EmojiParser.parse_tokens('Test :tropical_fish:') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end

 # 'Test <img src="unicode/1F420.png" alt=":tropical_fish:">'
```

**All symbols**

```
EmojiParser.parse_all('Test 🐠 :tropical_fish:') { |emoji| emoji.hex_inspect }

 # 'Test 1f420 1f420'
```

### File Paths

A helper is provided for formatting custom filepaths beyond the Gemoji default. This may be useful if you'd like to upload your images to a CDN, and simply reference them from there:

```
fish = Emoji.find_by_alias('tropical_fish')
EmojiParser.filepath(fish, '//cdn.fu/emoji/')
 # "//cdn.fu/emoji/1F420.png"
```

## Shoutout

Thanks to the GitHub team for the [Gemoji](https://github.com/github/gemoji) gem. They're handling all the heavy lifting.

## Contributing

1. Fork it ( https://github.com/gmac/gemoji-parser/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
