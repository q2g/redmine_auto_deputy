require "spec_helper"
RSpec.describe RedmineAutoDeputy::UserAvailabilityExtension do

  specify { expect(User.included_modules).to include(described_class)}

  describe 'validate_unavailabilities on before_save' do
    let(:filter) { User._save_callbacks.select {|c| c.kind ==  :before && c.filter == :validate_unavailabilities }.first }
    specify { expect(filter).not_to be(nil) }
  end


  describe '#unavailablity_set?' do
    context 'nothing set' do
      let(:user) { build_stubbed(:user) }
      specify { expect(user.unavailablity_set?).to be(false) }
    end

    context 'values set' do
      let(:user) { build_stubbed(:user, unavailable_from: Time.now+1.day, unavailable_to: Time.now+2.days) }
      specify { expect(user.unavailablity_set?).to be(true) }
    end
  end

  describe '#available_at?'do
    context 'with unavailablilty set' do
      let(:user) { build_stubbed(:user, unavailable_from: (Time.now+1.day).to_date, unavailable_to: (Time.now+4.days).to_date) }

      specify { expect(user.available_at?).to be(true) }
      specify { expect(user.available_at?(Time.now+1.day)).to be(false) }
      specify { expect(user.available_at?(Time.now+3.days)).to be(false) }
      specify { expect(user.available_at?(Time.now+4.days)).to be(false) }
      specify { expect(user.available_at?(Time.now+5.days)).to be(true) }
    end

    context 'without unavailablilty set' do
      let(:user) { build_stubbed(:user) }
      specify { expect(user.available_at?(Time.now)).to be(true)}
    end

  end

end