#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'json'
require 'rss'
require 'open-uri'

feed_url = "https://feed.podbean.com/thexyzpod/feed.xml"
root_dir = Dir.pwd
data_dir = File.join(root_dir,'_data')
episode_dir = File.join(root_dir,'_episodes')
post_dir = File.join(root_dir,'_posts')
extra_dir = File.join(root_dir,'_extra')
json_file = File.join(data_dir,'metadata.json')

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: readrss.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-j", "--json", "Generate JSON Meta Data") do |g|
    options[:json] = g
  end

  opts.on("-p", "--pages", "Generate Pages for Episodes") do |p|
    options[:pages] = p
  end
end.parse!

if options[:json]
    puts "Generating JSON Metadata File" unless not options[:verbose]

    if not File.exist?(json_file)
        File.open(json_file,"w") { |file| file.write("{}") }
    end
    
    data = JSON.parse(File.read(json_file))
    
    URI.open(feed_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|

        episode = {}

        puts "Processing: " + item.link unless not options[:verbose]

        if not data[item.link]
            puts "New Episode: " + item.title unless not options[:verbose]
            episode["title"] = item.title
            episode["spotify"] = ''
            episode["apple"] = ''
            episode["youtube"] = ''
            episode["extra"] = ''
            episode["categories"] = []
        else
            episode = data[item.link]
        end

        categories = episode["categories"]

        if item.title.match(/(with [A-Z]+|Bryan|Yoga|Hanging in)/)
            categories.push('guest') unless categories.include? 'guest'
        end

        if item.title.match(/(swiss|switzerland|schweiz|liechtenstein|midwife)/i)
            categories.push('switzerland') unless categories.include? 'switzerland'
        end

        if item.title.match(/(tinder|breakup|is love|sex|are men|assholes)/i)
            categories.push('dating') unless categories.include? 'dating'
        end

        if item.title.match(/(conspiracy|apocalypse|religion|social media|future|reboot|burnout|life|death|woke|addiction|gamestop|toilet|vaccine|idolize|revolution|positivity|19 years|yoga|meditate)/i)
            categories.push('deep') unless categories.include? 'deep'
        end

        if item.title.match(/(dreams|childhood|cooking|reboot|burnout|road|therapy|annoying|deep dive)/i)
            categories.push('oversharing') unless categories.include? 'oversharing'
        end

        if item.title.match(/(caro|ahmet|delahaye|vokey|moritz|mateo|capper|comedy)/i)
            categories.push('comedy') unless categories.include? 'comedy'
        end

        episode["categories"] = categories

        data[item.link] = episode
        puts episode unless not options[:verbose]
      end
    end

    File.open(json_file,"w") {
        |file| file.write(JSON.pretty_generate(data))
    }
end

def friendly_filename(filename)
    filename.gsub(/[^\w\s_-]+/, '')
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            .gsub(/\s+/, '_')
end

def padded(x)
    if x.to_s.length == 1
        return "0"+x.to_s
    else
        return x.to_s
    end
end


if options[:pages]
    data = JSON.parse(File.read(json_file))

    URI.open(feed_url) do |rss|
        feed = RSS::Parser.parse(rss)
        first = true
        feed.items.each do |item|
            date = "%s-%s-%s" % [item.pubDate.year,padded(item.pubDate.month),padded(item.pubDate.day)]
            time = "%s:%s" % [padded(item.pubDate.hour),padded(item.pubDate.min)]
            filename = "%s.html" % [friendly_filename(item.title)]
            # puts item.itunes_duration.content
            # puts item.itunes_image.href
            categories = data[item.link]['categories'].join(' ')

            extra = ""
            if not data[item.link]['extra'].empty?
                extra = File.read(File.join(extra_dir,data[item.link]['extra']))
            end
            # puts extra

            description = item.description.gsub(/<p>More about.*<\/a><\/p>/,'')

            page = <<-PAGE
---
layout: episodes
date: #{date} #{time}
title: #{item.title}
categories: #{categories}
image: #{item.itunes_image.href}
link: #{item.link}
spotify: #{data[item.link]['spotify']}
apple: #{data[item.link]['apple']}
youtube: #{data[item.link]['youtube']}
---
<div class="episodes>
    <span class="description">#{description}</span>

    {% if page.spotify %}
    <a href="{{ page.spotify }}" class="button" target="_blank">Listen to Episode on Spotify</a>
    {% endif %}

    {% if page.apple %}
    <a href="{{ page.apple }}" class="button" target="_blank">Listen to Episode on Apple Podcasts</a>
    {% endif %}

    {% if page.youtube %}
    <a href="{{ page.youtube }}" class="button" target="_blank">Watch Episode on YouTube</a>
    {% endif %}

    #{extra}

    <div class="more">
        <h2>More Episodes</h2>
        <ul class="episodes">
            {% assign n = site.episodes | where_exp: "item", "item.categories contains page.categories[0]" | where_exp:"item",
            "item.title != page.title" | size %}
            {% assign episodes = site.episodes | where_exp: "item", "item.categories contains page.categories[0]" | where_exp:"item",
            "item.title != page.title" | sample: n | slice:0, 3 %}
            {% if n == 0 %}
                {% assign n = site.episodes | where_exp:"item", "item.title != page.title" | size %}
                {% assign episodes = site.episodes | where_exp:"item","item.title != page.title" | sample: n | slice:0, 3 %}
            {% endif %}
            {% for episode in episodes %}
            <li>
                <a href="{{ site.url }}{{ episode.url }}">
                    <img class="selfie" src="{{ episode.image }}"/>
                    <h2><span>{{ episode.title }}</span></h2>
                </a>
            </li>
            {% endfor %}
        </ul>
    </div>
    
</div>

PAGE
            # puts page
            File.open(File.join(episode_dir,filename),"w") {
                |file| file.write(page)
            }

            # Update the "Latest" button to the new episode...
            if first
                # update latest
                latest = <<-LATEST
---
layout: post
date: 2020-08-24 22:48
title: Latest Episode
group: action
type: internal
image: #{item.itunes_image.href}
sitemap: false
---

{{ site.url }}/episodes/#{filename}
                
LATEST
                File.open(File.join(post_dir,"2021-03-16-LATEST.html"),"w") {
                    |file| file.write(latest)
                }
                first = false
            end
        end
    end
end