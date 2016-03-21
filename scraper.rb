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
  content = ''
  begin
    content = open(url).read
  rescue OpenURI::HTTPError => e
    # ignore errors because some of the pages return a 500
    # code even though the page works.
    content = e.io
  end
  Nokogiri::HTML(content)
end

def scrape_list(url, term)
  noko = noko_for(url) rescue nil
  if noko.nil?
      return
  end
  puts '%s - %s' % [url, term]
  noko.css('#Contenu a[href*="page=depute"]/@href').map(&:text).each do |href|
    scrape_mp(URI.join(url, href), term)
  end
end

def gender_from(name)
  return 'male' if name.start_with? 'Mr'
  return 'male' if name.start_with? 'M.'
  return 'female' if name.start_with? 'Mme'
  raise "Unknown gender for #{name}"
end

def scrape_mp(url, term)
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
    term: term,
  }
  data[:gender] = gender_from(data[:name])
  ScraperWiki.save_sqlite([:name, :term], data)
end

terms = [
    {
      id: 2012,
      name: '2012–2015',
      start_date: '2012-12-02',
      end_date: '2016-01-10',
      source: 'http://www.assembleenationale.bf/spip.php?article55',
    },
    {
      id: 2016,
      name: '2016–2019',
      start_date: '2016-01-02',
      source: 'http://www.assembleenationale.bf/Deputes-de-la-VIIeme-legislature',
    },
]

terms.each do |term|
    ScraperWiki.save_sqlite([:id], term, 'terms')
    scrape_list(term[:source], term[:id])
end
