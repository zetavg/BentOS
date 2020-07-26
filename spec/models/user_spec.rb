require 'rails_helper'

RSpec.describe User, type: :model do
  describe "relations" do
    it { is_expected.to have_many(:oauth_authentications) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "#from_oauth_authentication" do
    subject { User.from_oauth_authentication(oauth_authentication) }

    context "without existing user" do
      let(:oauth_authentication) { create(:user_oauth_authentication) }

      it "builds a new confirmed user without saving" do
        expect(subject).to have_attributes(
          name: oauth_authentication.user_name,
          email: oauth_authentication.user_email,
          picture_url: oauth_authentication.user_picture_url
        )
        expect(subject).to be_confirmed
        expect(subject).not_to be_persisted
        # expect subject.oauth_authentications contains oauth_authentication?
      end

      it "assigns the new user to the oauth_authentication and set sync_data to true without saving" do
        expect { subject }.to change { oauth_authentication.user }.from(nil)
        expect(oauth_authentication.user).to be(subject)
        expect(oauth_authentication.sync_data).to be(true)
      end
    end

    context "with existing user" do
      let(:oauth_authentication) { create(:user_oauth_authentication, :with_user) }

      it "returns the existing user without modification" do
        expect(subject).to be(oauth_authentication.user)
        expect(subject).to be_persisted
        expect(subject).not_to be_changed
      end

      context "sync_data is on" do
        let(:oauth_authentication) { create(:user_oauth_authentication, :with_user, :sync_data) }
        it "returns the existing user with data updated and confirmed without saving" do
          expect(subject).to have_attributes(
            name: oauth_authentication.user_name,
            email: oauth_authentication.user_email,
            picture_url: oauth_authentication.user_picture_url
          )
          expect(subject).to be_persisted
          expect(subject).to be_confirmed
          expect(subject.changed).to contain_exactly("name", "email", "picture_url")
        end
      end
    end
  end
end
