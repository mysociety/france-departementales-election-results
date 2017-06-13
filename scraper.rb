# frozen_string_literal: true

require 'bundler/setup'
require 'require_all'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

# require_rel 'lib'

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class PartyListPage < Scraped::HTML
  field :party_lookup do
    noko.css('.tableau-nuances tr').map { |row| row.css('td').map(&:text) }.to_h
  end
end

class ElectionResultsPage < Scraped::HTML
  field :region_urls do
    noko.css('#listeRG option/@value').drop(1).map do |result_url|
      URI.join(url, result_url).to_s
    end
  end
end

class RegionResultsPage < Scraped::HTML
  field :id do
    url.split('/').last.chomp('.html')
  end

  field :region_name do
    noko.css('.pub-resultats-entete h2:first').text
  end

  field :winner_name do
    winner_row.xpath('./td[1]/a/text()').text
  end

  field :winner_party_code do
    winner_row.xpath('./td[2]/text()').text
  end

  private

  def winner_row
    noko.xpath('.//table[1]/tbody/tr[1]')
  end
end

parties_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/nuances.html'
parties = scrape(parties_url => PartyListPage).party_lookup

results_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/index.html'
page = scrape(results_url => ElectionResultsPage)

page.region_urls.each do |url|
  region = scrape(url => RegionResultsPage)
  data = region.to_h
  data[:winner_party] = parties[data[:winner_party_code]]
  ScraperWiki.save_sqlite([:id], data)
end
