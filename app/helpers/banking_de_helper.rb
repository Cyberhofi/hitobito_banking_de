# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

module BankingDeHelper
  LEVEL_CLASSES = {sure: "bg-success", likely: "bg-info text-dark", possible: "bg-light text-dark"}
    .freeze

  def banking_de_amount(amount)
    number_to_currency(amount, unit: "€", format: "%n %u")
  end

  def banking_de_iban(iban, masked: false)
    masked ? BankingDe::Iban.mask(iban) : BankingDe::Iban.format(iban)
  end

  def banking_de_level_badge(candidate)
    content_tag(:span, t("banking_de.levels.#{candidate.level}"),
      class: "badge #{LEVEL_CLASSES[candidate.level]}")
  end

  def banking_de_reasons(candidate)
    candidate.reasons.map { |r| t("banking_de.reasons.#{r}") }.join(", ")
  end

  def banking_de_kind(booking)
    t("banking_de.kinds.#{booking.kind}")
  end

  def banking_de_return_reason(code)
    return if code.blank?

    label = t("banking_de.return_reasons.#{code}", default: "")
    label.present? ? "#{code} – #{label}" : code
  end

  def banking_de_purpose_options(selected)
    options_for_select(BankingDe.purposes.values.map { |p| [p.label, p.key] }, selected)
  end

  def banking_de_person_options(people, candidates, selected)
    suggested = candidates.map(&:person)
    groups = {}
    if suggested.any?
      groups[t("banking_de.bookings.form.suggested")] = suggested.map do |p|
        [banking_de_person_label(p), p.id]
      end
    end
    groups[t("banking_de.bookings.form.all_people")] = people.map { |p|
      [banking_de_person_label(p), p.id]
    }
    grouped_options_for_select(groups, selected)
  end

  # Name with year of birth to tell apart people with the same name
  def banking_de_person_label(person)
    [person.to_s(:list), person.birthday&.year&.then { |y| "(#{y})" }].compact.join(" ")
  end

  def banking_de_rows_summary(rows)
    rows.map do |row|
      purpose = BankingDe.purposes[row.purpose.to_s]&.label
      [purpose, row.year, banking_de_amount(row.amount)].compact.join(" ")
    end.join(" + ")
  end

  def banking_de_mandate_state(account)
    state = account.mandate_state
    css = {active: "bg-success", revoked: "bg-secondary", blocked: "bg-danger",
           none: "bg-light text-dark"}
    content_tag(:span, t("banking_de.mandate_states.#{state}"), class: "badge #{css[state]}")
  end
end
