# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Bank account and mandate of a person: only people with the finance permission. The
# data is not part of person exports and not shown to anybody else, the person included.
module BankingDe::PersonAbility
  extend ActiveSupport::Concern

  included do
    on(Person) do
      permission(:finance)
        .may(:show_bank_account, :update_bank_account)
        .in_same_layer_or_below
    end
  end
end
