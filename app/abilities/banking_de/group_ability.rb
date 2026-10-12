# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Account statement import of a layer: people with the finance permission in this layer.
module BankingDe::GroupAbility
  extend ActiveSupport::Concern

  included do
    on(Group) do
      permission(:finance).may(:manage_bank_bookings).in_same_layer
    end
  end
end
