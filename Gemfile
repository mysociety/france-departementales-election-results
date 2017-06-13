# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.4.1'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'open-uri-cached'
gem 'require_all'
gem 'scraped', github: 'everypolitician/scraped'
gem 'scraperwiki', github: 'openaustralia/scraperwiki-ruby',
                   branch: 'morph_defaults'

group :development do
  gem 'pry'
  gem 'rake'
  gem 'rubocop'
end

group :test do
  gem 'scraper_test', github: 'everypolitician/scraper_test'
end
