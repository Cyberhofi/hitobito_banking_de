$LOAD_PATH.push File.expand_path("../lib", __FILE__)

require "hitobito_banking_de/version"

Gem::Specification.new do |s|
  s.name = "hitobito_banking_de"
  s.version = HitobitoBankingDe::VERSION
  s.authors = ["Stefan Hofmann"]
  s.email = ["mail@stefanhofmann.net"]
  s.homepage = "https://github.com/Cyberhofi/hitobito_banking_de"
  s.license = "AGPL-3.0-or-later"
  s.summary = "German banking for hitobito: account statement import (camt) and SEPA mandates"
  s.description = "Organization-neutral hitobito wagon: imports camt.052/camt.053 account " \
                  "statements, suggests the people behind incoming payments, books them only " \
                  "after confirmation via pluggable purposes and keeps bank accounts and " \
                  "SEPA direct debit mandates of people."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
end
