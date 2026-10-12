# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

load File.expand_path("../app_root.rb", __dir__)
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
# Organization-neutral wagon: run against the core test group structure and fixtures
ENV["RAILS_USE_TEST_GROUPS"] = "true"

require File.join(ENV["APP_ROOT"], "spec", "spec_helper.rb")

Dir[HitobitoBankingDe::Wagon.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Use the fixtures of the core (no own fixtures), also when run from the wagon directory
  config.fixture_paths = [File.join(ENV["APP_ROOT"], "spec", "fixtures")]
  config.file_fixture_path = File.join(ENV["APP_ROOT"], "spec", "fixtures", "files")
end
