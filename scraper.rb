#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraperwiki'
require 'scraped'
require 'pry'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko_for(url)
  # The server returns a 500 error for a successful page!
  Nokogiri::HTML(open(url).read)
rescue => e
  text = e.io.read
  Nokogiri::HTML text
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('#Contenu a[href*="page=depute"]/@href').map(&:text).each do |href|
    scrape_mp(URI.join(url, href))
  end
end

def gender_from(name)
  return 'male' if name.start_with? 'M.'
  return 'female' if name.start_with? 'Mme'
  return '' if name.start_with? 'Dr'
  warn "Unknown gender for #{name}"
  ''
end

def scrape_mp(url)
  noko = noko_for(url) or return warn "Can't open #{url}"
  box = noko.css('#Contenu table.sancel')
  party_info = box.xpath('.//td[contains(.,"Parti politique")]/following-sibling::td').text
  party, party_id = party_info.split(' - ')

  data = {
    id:       url.to_s[/id=(\d+)/, 1],
    name:     box.css('span.link1').xpath('./text()[1]').text.gsub(/[[:space:]]+/, ' ').tidy,
    party:    party,
    party_id: party_id,
    area:     box.xpath('.//td[contains(.,"Liste provinciale")]/following-sibling::td[1]').text,
    email:    box.css('a[href*="mailto"]/@href').text.sub('mailto:', ''),
    image:    box.css('img[src*="photos"]/@src').text,
    term:     7,
    source:   url.to_s,
  }
  data[:gender] = gender_from(data[:name])
  # puts data
  ScraperWiki.save_sqlite(%i[id term], data)
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('http://www.assembleenationale.bf/Deputes-de-la-VIIeme-legislature')
