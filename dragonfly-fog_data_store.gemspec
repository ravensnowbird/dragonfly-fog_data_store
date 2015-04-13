# -*- encoding: utf-8 -*-
# stub: dragonfly-fog_data_store 0.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "dragonfly-fog_data_store"
  s.version = "0.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["jimmy"]
  s.date = "2014-12-27"
  s.description = "fog data store for Dragonfly"
  s.files = [".gitignore", "Gemfile", "LICENSE.txt", "README.md", "Rakefile", "dragonfly-fog_data_store.gemspec", "lib/dragonfly/fog_data_store.rb", "lib/dragonfly/fog_data_store/version.rb", "spec/fog_data_store_spec.rb", "spec/spec_helper.rb"]
  s.homepage = "https://github.com/markevans/dragonfly-fog_data_store"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "Data store for storing Dragonfly content (e.g. images) on fog"
  s.test_files = ["spec/fog_data_store_spec.rb", "spec/spec_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<dragonfly>, ["~> 1.0"])
      s.add_runtime_dependency(%q<fog>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.0"])
    else
      s.add_dependency(%q<dragonfly>, ["~> 1.0"])
      s.add_dependency(%q<fog>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.0"])
    end
  else
    s.add_dependency(%q<dragonfly>, ["~> 1.0"])
    s.add_dependency(%q<fog>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.0"])
  end
end
