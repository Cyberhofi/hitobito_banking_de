# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

module HitobitoBankingDe
  class Wagon < Rails::Engine
    include Wagons::Wagon

    app_requirement ">= 0"

    config.autoload_paths += %W[
      #{config.root}/app/abilities
      #{config.root}/app/domain
    ]

    config.to_prepare do
      PersonAbility.include BankingDe::PersonAbility
      GroupAbility.include BankingDe::GroupAbility
      Person.include BankingDe::Person
      Sheet::Group.include BankingDe::Sheet::Group
    end
  end
end
