# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Finds people whose names appear in a text (payer name and remittance information).
# Bank texts are often upper case and without umlauts ("MUELLER", "MULLER" for Müller),
# so names and text are compared in several spellings.
class BankingDe::NameIndex
  MIN_LENGTH = 3

  def initialize(people)
    @people = people.index_by(&:id)
    @by_last_name = Hash.new { |h, k| h[k] = [] }
    people.each do |person|
      parts = name_parts(person.last_name)
      parts.first&.each { |spelling| @by_last_name[spelling] << [person, parts] }
    end
  end

  def person(id)
    @people[id]
  end

  # Returns [[person, first_name_found], ...] for all people whose last name parts all
  # appear in the text
  def matches(text)
    tokens = tokens(text)
    @by_last_name.slice(*tokens).values.flatten(1).uniq.filter_map do |person, parts|
      next unless parts.all? { |variants| found?(variants, tokens) }

      first_names = name_parts([person.first_name, person.nickname].compact.join(" "))
      [person, first_names.any? { |variants| found?(variants, tokens) }]
    end
  end

  private

  def found?(variants, tokens)
    variants.any? { |variant| tokens.include?(variant) }
  end

  # Every name part with its spellings, e.g. "Groß-Müller" => [[gross], [mueller, muller]]
  def name_parts(name)
    words(name).map { |word| spellings(word).to_a }.reject(&:empty?)
  end

  def tokens(text)
    words(text).flat_map { |word| spellings(word).to_a }.to_set
  end

  def words(text)
    text.to_s.split(/[^[:alpha:]]+/).reject { |w| w.length < MIN_LENGTH }
  end

  def spellings(word)
    word = word.downcase
    [
      word.gsub("ä", "ae").gsub("ö", "oe").gsub("ü", "ue").gsub("ß", "ss"),
      word.tr("äöü", "aou").gsub("ß", "ss"),
      I18n.transliterate(word).downcase
    ].map { |w| w.gsub(/[^a-z]/, "") }.reject { |w| w.length < MIN_LENGTH }.to_set
  end
end
