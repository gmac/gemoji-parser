require 'net/http'

namespace :db do

  desc 'Outputs default emoticon set'
  task :scores do
    data = Net::HTTP.get(URI('http://www.emojitracker.com/api/rankings'))
    data = JSON.parse(data)

    scores = {}

    # Confirm sort order, then format fields:
    data.each do |emoji|
      scores[emoji['char']] = {
        :id => emoji['id'].downcase,
        :score => emoji['score'].to_i
      }
    end

    fp = 'db/scores.json'
    f = File.open(fp, 'w')
    f.puts JSON.generate(scores)
    f.close
    puts "write: #{fp}"
  end

end