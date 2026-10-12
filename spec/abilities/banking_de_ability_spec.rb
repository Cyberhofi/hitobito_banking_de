# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe Ability do
  subject(:ability) { Ability.new(user) }

  context "with finance permission in the top layer" do
    let(:user) { people(:top_leader) }

    it "may manage bookings of the layer and bank accounts below" do
      expect(ability).to be_able_to(:manage_bank_bookings, groups(:top_layer))
      expect(ability).to be_able_to(:show_bank_account, people(:bottom_member))
      expect(ability).to be_able_to(:update_bank_account, people(:bottom_member))
    end

    it "may not manage bookings of layers below" do
      expect(ability).not_to be_able_to(:manage_bank_bookings, groups(:bottom_layer_one))
    end
  end

  context "with full layer permission but without finance" do
    let(:user) { Fabricate(Group::TopGroup::LocalGuide.sti_name, group: groups(:top_group)).person }

    it "may not see bank data" do
      expect(ability).not_to be_able_to(:manage_bank_bookings, groups(:top_layer))
      expect(ability).not_to be_able_to(:show_bank_account, people(:bottom_member))
    end
  end

  context "as member without finance permission" do
    let(:user) do
      Fabricate(Group::BottomGroup::Member.sti_name, group: groups(:bottom_group_one_one)).person
    end

    it "may not see the own bank data" do
      expect(ability).not_to be_able_to(:show_bank_account, user)
      expect(ability).not_to be_able_to(:update_bank_account, user)
    end
  end
end
