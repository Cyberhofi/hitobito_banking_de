# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Tab "Kontoimport" on layer groups for people with the finance permission
module BankingDe::Sheet::Group
  extend ActiveSupport::Concern

  included do
    tabs.insert(
      -3,
      ::Sheet::Tab.new("banking_de.tabs.bookings",
        :group_bank_bookings_path,
        params: {returning: true},
        alt: [:group_bank_statements_path, :new_group_bank_statement_path],
        if: (lambda do |view, group|
          group.layer? && view.can?(:manage_bank_bookings, group)
        end))
    )
  end
end
