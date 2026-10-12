# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# One imported account report (camt.052) or statement (camt.053) of an own account
class BankingDe::Statement < ActiveRecord::Base
  belongs_to :group, class_name: "::Group"
  belongs_to :imported_by, class_name: "::Person", optional: true
  has_many :bookings, class_name: "BankingDe::Booking", dependent: :restrict_with_error

  scope :list, -> { order(to_date: :desc, from_date: :desc, id: :desc) }

  def to_s
    [from_date, to_date].compact.uniq.map { |d| I18n.l(d) }.join(" – ")
  end
end
