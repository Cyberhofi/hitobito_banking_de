# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Checks whether the imported statements of an account are complete: the closing balance
# of a statement must be the opening balance of the next one. Otherwise statements
# (days with bookings) are missing in between.
class BankingDe::StatementContinuity
  Gap = Struct.new(:account_iban, :after, :before, keyword_init: true)

  def initialize(group)
    @group = group
  end

  def gaps
    statements.group_by(&:account_iban).flat_map do |iban, list|
      list.each_cons(2).filter_map do |previous, current|
        next unless gap?(previous, current)

        Gap.new(account_iban: iban, after: previous.to_date, before: current.from_date)
      end
    end
  end

  # Latest statement per account
  def latest
    statements.group_by(&:account_iban).transform_values(&:last)
  end

  private

  def gap?(previous, current)
    previous.closing_balance && current.opening_balance &&
      previous.closing_balance != current.opening_balance
  end

  def statements
    @statements ||= BankingDe::Statement.where(group: @group)
      .order(:account_iban, :from_date, :to_date, :id).to_a
  end
end
