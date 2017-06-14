# frozen_string_literal: true

require 'bundler/setup'
require 'require_all'
require 'scraped'
require 'scraperwiki'
require 'active_support'
require 'active_support/core_ext'
require 'htmlentities'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

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
  field :department_urls do
    noko.css('#listeDpt option/@value').drop(1).map(&:to_s).map do |result_url|
      URI.join(url, result_url).to_s
    end
  end
end

class DepartmentResultsPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :canton_urls do
    noko.css('.pub-resultats-entete .pub-index-communes a/@href').map(&:text)
  end
end

class CantonResultsPage < Scraped::HTML
  field :councillor_names do
    noko.xpath('.//table[1]/tbody/tr[1]/td/text()').take(2).map do |name|
      HTMLEntities.new.decode(name.to_s)
    end
  end

  field :area_name do
    area[:name]
  end

  field :area_id do
    area[:id]
  end

  field :parent_area_name do
    parent_area[:name]
  end

  field :parent_area_id do
    parent_area[:id]
  end

  field :party_code do
    winner_row.xpath('./td[2]').text
  end

  private

  def winner_row
    noko.xpath('.//table[1]/tbody/tr[1]')
  end

  def area_parts
    noko.at_css('h3').text.split(' - ')
  end

  def parent_area
    area_parts.first.match(/^(?<name>.+) \((?<id>\d+)\)/)
  end

  def area
    area_parts.last.match(/^canton de (?<name>.+) \((?<id>\d+)\)/)
  end
end

parties_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/nuances.html'
parties = scrape(parties_url => PartyListPage).party_lookup

results_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/index.html'
page = scrape(results_url => ElectionResultsPage)

page.department_urls.each do |url|
  department = scrape(url => DepartmentResultsPage)
  department.canton_urls.each do |canton_url|
    data = scrape(canton_url => CantonResultsPage).to_h
    names = data.delete(:councillor_names)
    names.each do |name|
      ScraperWiki.save_sqlite([:id], data.merge(name: name, id: name.parameterize, party_name: parties[data[:party_code]]))
    end
  end
end
