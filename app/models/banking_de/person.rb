# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Bank data of a person. Kept in own tables, so it is not part of any person export.
module BankingDe::Person
  extend ActiveSupport::Concern

  included do
    has_one :banking_de_bank_account, class_name: "BankingDe::BankAccount", dependent: :destroy
    has_many :banking_de_allocations, class_name: "BankingDe::Allocation",
      dependent: :restrict_with_error
  end
end
