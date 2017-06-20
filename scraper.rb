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
  field :councillors do
    noko.xpath('.//table[1]/tbody/tr[1]/td[1]').children.select(&:text?).map do |councillor|
      fragment(councillor => Councillor)
    end
  end
end

class Councillor < Scraped::HTML
  field :id do
    name.parameterize
  end

  field :name do
    HTMLEntities.new.decode(noko.text.to_s)
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
    noko.xpath('../../td[2]').text
  end

  field :gender do
    name.match(/^M\. /) ? 'M' : name.gsub(/^Mme /) ? 'F' : ''
  end

  private

  def area_parts
    noko.xpath('//h3[1]').text.split(' - ', 2)
  end

  def parent_area
    area_parts.first.match(/^(?<name>.+) \((?<id>\w+)\)/)
  end

  def area
    area_parts.last.match(/^canton de (?<name>.+) \((?<id>\w+)\)/)
  end
end

parties_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/nuances.html'
parties = scrape(parties_url => PartyListPage).party_lookup

results_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/index.html'

scrape(results_url => ElectionResultsPage).department_urls.each do |department_url|
  scrape(department_url => DepartmentResultsPage).canton_urls.each do |canton_url|
    scrape(canton_url => CantonResultsPage).councillors.each do |councillor|
      ScraperWiki.save_sqlite([:id], councillor.to_h.merge(party_name: parties[councillor.party_code]))
    end
  end
end
