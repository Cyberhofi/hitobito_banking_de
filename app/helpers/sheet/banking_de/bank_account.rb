# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

module Sheet
  module BankingDe
    class BankAccount < Sheet::Base
      self.parent_sheet = Sheet::Person

      def title
        ::BankingDe::BankAccount.model_name.human
      end
    end
  end
end
