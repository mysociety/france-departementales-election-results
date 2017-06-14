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
    noko.css('#listeDpt option/@value').drop(1).map do |result_url|
      code = result_url.to_s.split('/').first
      URI.join(url, [code, "CD#{code}.html"].join('/')).to_s
    end
  end
end

class DepartmentResultsPage < Scraped::HTML
  field :councillors do
    noko.css('table tbody tr').flat_map do |row|
      area = row.css('td').first.text
      match = area.match(/^(?<name>.+) \((?<id>\d+)\)/)
      names = row.css('td').last.children.select(&:text?)
      names.map do |noko_name|
        name = HTMLEntities.new.decode(noko_name.to_s)
        {
          id: name.parameterize,
          name: name,
          area_name: match[:name],
          area_id: match[:id],
        }
      end
    end
  end
end

# parties_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/nuances.html'
# parties = scrape(parties_url => PartyListPage).party_lookup

results_url = 'https://www.interieur.gouv.fr/Elections/Les-resultats/Departementales/elecresult__departementales-2015/(path)/departementales-2015/index.html'
page = scrape(results_url => ElectionResultsPage)

page.department_urls.each do |url|
  region = scrape(url => DepartmentResultsPage)
  data = region.councillors
  ScraperWiki.save_sqlite([:id], data)
end
