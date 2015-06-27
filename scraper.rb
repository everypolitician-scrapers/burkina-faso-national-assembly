#!/bin/env ruby
# encoding: utf-8

require 'nokogiri'
require 'open-uri'
require 'csv'
require 'scraperwiki'
require 'pry'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('#Contenu a[href*="page=depute"]/@href').map(&:text).each do |href|
    scrape_mp(URI.join url, href)
  end
end

def gender_from(name)
  return 'male' if name.start_with? 'Mr'
  return 'female' if name.start_with? 'Mme'
  raise "Unknown gender for #{name}"
end

def scrape_mp(url)
  noko = noko_for(url)
  box = noko.css('#Contenu table.sancel')
  party_info = box.xpath('.//td[contains(.,"Parti politique")]/following-sibling::td').text
  party, party_id = party_info.split(' - ')

  data = { 
    id: url.to_s[/id=(\d+)/, 1],
    name: box.css('span.link1').xpath('./text()[1]').text.gsub(/[[:space:]]+/, ' ').strip,
    party: party,
    party_id: party_id,
    area: box.xpath('.//td[contains(.,"Liste provinciale")]/following-sibling::td[1]').text,
    email: box.css('a[href*="mailto"]/@href').text.sub('mailto:',''),
    image: box.css('img[src*="photos"]/@src').text,
    term: 2012,
  }
  data[:gender] = gender_from(data[:name])
  puts data
  ScraperWiki.save_sqlite([:name, :term], data)
end

term = {
  id: 2012,
  name: '2012–2015',
  start_date: '2012-12-02',
}
ScraperWiki.save_sqlite([:id], term, 'terms')


scrape_list('http://www.assembleenationale.bf/spip.php?article55')
