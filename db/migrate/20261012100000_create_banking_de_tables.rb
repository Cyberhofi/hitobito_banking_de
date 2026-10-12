#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

class CreateBankingDeTables < ActiveRecord::Migration[8.0]
  def change
    # Bank account and SEPA direct debit mandate of a person
    create_table :banking_de_bank_accounts do |t|
      t.belongs_to :person, null: false, index: {unique: true}
      t.string :iban, null: false, limit: 34
      t.string :account_holder
      t.string :mandate_reference, limit: 35
      t.date :mandate_signed_on
      t.date :mandate_revoked_on
      t.string :last_return_reason, limit: 4
      t.date :last_return_on
      t.string :source, null: false, default: "manual"
      t.belongs_to :created_by
      t.belongs_to :updated_by
      t.timestamps
    end
    add_index :banking_de_bank_accounts, :iban
    add_index :banking_de_bank_accounts, :mandate_reference, unique: true,
      where: "mandate_reference IS NOT NULL"

    # One account report or statement (camt.052 / camt.053) of the own account
    create_table :banking_de_statements do |t|
      t.belongs_to :group, null: false
      t.string :account_iban, null: false, limit: 34
      t.string :message_type, null: false
      t.string :statement_id
      t.date :from_date
      t.date :to_date
      t.decimal :opening_balance, precision: 12, scale: 2
      t.decimal :closing_balance, precision: 12, scale: 2
      t.string :filename
      t.belongs_to :imported_by
      t.timestamps
    end
    add_index :banking_de_statements, [:account_iban, :to_date]

    # Relevant entries of a statement: incoming payments and returned direct debits
    create_table :banking_de_bookings do |t|
      t.belongs_to :statement, null: false
      t.belongs_to :group, null: false
      t.string :account_iban, null: false, limit: 34
      t.string :bank_reference, null: false
      t.string :kind, null: false
      t.string :state, null: false, default: "open"
      t.date :booking_date, null: false
      t.date :value_date
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :counterparty_name
      t.string :counterparty_iban, limit: 34
      t.text :remittance_information
      t.string :end_to_end_id
      t.string :mandate_reference
      t.string :payment_information_id
      t.string :return_reason, limit: 4
      t.string :bank_transaction_code
      t.text :note
      t.belongs_to :processed_by
      t.datetime :processed_at
      t.timestamps
    end
    add_index :banking_de_bookings, [:account_iban, :bank_reference], unique: true
    add_index :banking_de_bookings, [:group_id, :state]

    # Confirmed assignment of (a part of) a transaction to a person and a purpose
    create_table :banking_de_allocations do |t|
      t.belongs_to :booking, null: false
      t.belongs_to :person, null: false
      t.string :purpose, null: false
      t.integer :year
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.json :effect
      t.belongs_to :created_by
      t.timestamps
    end
  end
end
