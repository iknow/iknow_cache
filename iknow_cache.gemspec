$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "iknow_cache/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "iknow_cache"
  s.version     = IknowCache::VERSION
  s.authors     = ["Chris Andreae"]
  s.email       = ["chris@bibo.com.ph"]
  s.summary     = "iKnow's versioned nested cache"
  s.homepage    = "https://github.com/iknow/iknow_cache"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.0.1"

  s.add_development_dependency "sqlite3"
end
