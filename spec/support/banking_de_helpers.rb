# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

module BankingDeHelpers
  OWN_IBAN = "DE59855500001000000000"
  MEMBER_IBAN = "DE52120300001111111111"
  OTHER_IBAN = "DE71850500002222222222"

  Upload = Struct.new(:original_filename, :data) do
    def read(length = nil)
      length ? data.byteslice(0, length) : data
    end
  end

  # The core fixture files are needed by the core fixtures, so own files are read directly
  def camt_file(name)
    HitobitoBankingDe::Wagon.root.join("spec", "fixtures", "files", name)
  end

  def camt_upload(name)
    Upload.new(name, camt_file(name).binread)
  end

  def zip_upload(*names)
    buffer = Zip::OutputStream.write_buffer do |zip|
      names.each do |name|
        zip.put_next_entry("export/#{name}")
        zip.write(camt_file(name).binread)
      end
    end
    Upload.new("export.zip", buffer.string)
  end

  def import_camt(*names, group: groups(:top_layer), user: people(:top_leader))
    BankingDe::StatementImport.new(group, user).import(names.map { |n| camt_upload(n) })
  end

  # Purposes of a club with a yearly fee and a compensation for unperformed work hours.
  # apply/revert write into a log so the specs can check the calls.
  def register_test_purposes
    log = []
    BankingDe.register_purpose(:membership_fee, amount: 85, yearly: true, primary: true,
      apply: lambda { |a|
        log << [:apply, a.person_id, a.year, a.amount]
        {"year" => a.year}
      },
      revert: ->(a) { log << [:revert, a.person_id, a.year, a.effect] })
    BankingDe.register_purpose(:work_hours, amount: 20, yearly: true)
    log
  end
end

RSpec.configure do |config|
  config.include BankingDeHelpers

  config.around do |example|
    purposes = BankingDe.purposes.dup
    example.run
  ensure
    BankingDe.purposes.replace(purposes)
  end
end
