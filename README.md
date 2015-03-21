# gemoji-parser

The missing helper methods for [GitHub's Gemoji](https://github.com/github/gemoji) gem. This utility provides a parsing API for the `Emoji` corelib (provided by Gemoji). The parser handles transformations of emoji symbols between unicode (😃), token (`:smile:`), and emoticon (`:-D`) formats; and may perform arbitrary replacement of emoji symbols into custom display formats (such as image tags). Internally, the parses generates highly-optimized regular expressions to maximize parsing performance.
�
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

The tokenizer methods perform basic conversions of unicode symbols into token symbols, and vice versa.

```ruby
EmojiParser.tokenize("Test 🙈 🙊 🙉")
# "Test :see_no_evil: :speak_no_evil: :hear_no_evil:"

EmojiParser.detokenize("Test :see_no_evil: :speak_no_evil: :hear_no_evil:")
# "Test 🙈 🙊 🙉"
```

### Symbol Parsing

Use the symbol parser methods for custom transformations. All symbol parsers yeild [Emoji::Character](https://github.com/github/gemoji/blob/master/lib/emoji/character.rb) instances into the parsing block for custom formatting.

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

**All symbol types**

Use the `parse` method to target multiple symbol types with a single parsing pass. Specific symbol formats to target may be passed as options:

```ruby
EmojiParser.parse('Test 🐠 :scream: ;-)') { |emoji| "[#{emoji.name}]" }
# 'Test [tropical_fish] [scream] [wink]'

EmojiParser.parse('Test 🐠 :scream: ;-)', unicode: true, tokens: true) do |emoji|
  "[#{emoji.name}]"
end
# 'Test [tropical_fish] [scream] ;-)'
```

While the `parse` method is heavier to run than the discrete parsing methods for each symbol type (`parse_unicode`, etc...), it has the advantage of avoiding multiple parsing passes. This is handy if you want parsed symbols to output new symbols in a different format, such as generating image tags that include a symbol in their alt text:

```ruby
EmojiParser.parse('Test 🐠 ;-)') do |emoji|
  %Q(<img src="#{emoji.image_filename}" alt=":#{emoji.name}:">).html_safe
end
# 'Test <img src="unicode/1f420.png" alt=":tropical_fish:"> <img src="unicode/1f609.png" alt=":wink:">'
```

### Lookups & File Paths

Use the `find` method to derive `Emoji::Character` instances from any symbol format (unicode, token, emoticon):

```ruby
emoji = EmojiParser.find(🐠)
emoji = EmojiParser.find('tropical_fish')
emoji = EmojiParser.find(';-)')
```

Use the `filepath` method to derive an image filepath from any symbol format (unicode, token, emoticon). You may optionally provide a custom path that overrides the Gemoji default location (this is useful if you'd like to reference your images from a CDN):

```ruby
EmojiParser.filepath('tropical_fish')
# "unicode/1f420.png"

EmojiParser.filepath('tropical_fish', '//cdn.fu/emoji/')
# "//cdn.fu/emoji/1f420.png"
```

## Custom Symbols

**Emoji**

The parser plays nicely with custom emoji defined through the Gemoji core. You just need to call `rehash!` once after adding new emoji symbols to regenerate the parser's regex cache:

```ruby
Emoji.create('boxing_kangaroo') # << WHY IS THIS NOT STANDARD?!
EmojiParser.rehash!
```

**Emoticons**

Emoticon patterns are defined through the parser, and are simply mapped to an emoji name that exists within the Gemoji core (this can be a standard emoji, or a custom emoji that you have added). To see the built-in emoticons, simply inspect the `EmojiParser.emoticons` hash. For custom emoticons:

```ruby
# Alias a standard emoji:
EmojiParser.emoticons[':@'] = :angry

# Create a custom emoji, and alias it:
Emoji.create('bill_clinton')
EmojiParser.emoticons['=:o]'] = :bill_clinton

# IMPORTANT: rehash once after adding new symbols to Emoji core, or to the EmojiParser:
EmojiParser.rehash!
```

## Shoutout

Thanks to the GitHub team for the [Gemoji](https://github.com/github/gemoji) gem, and my esteemed colleague Michael Lovitt for the fantastic [Rubular](http://rubular.com/) regex tool.
