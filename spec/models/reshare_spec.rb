require "spec_helper"

describe Reshare, type: :model do
  it "has a valid Factory" do
    expect(FactoryGirl.build(:reshare)).to be_valid
  end

  it "requires root" do
    reshare = FactoryGirl.build(:reshare, root: nil)
    expect(reshare).not_to be_valid
  end

  it "require public root" do
    reshare = FactoryGirl.build(:reshare, root: FactoryGirl.create(:status_message, public: false))
    expect(reshare).not_to be_valid
    expect(reshare.errors[:base]).to include("Only posts which are public may be reshared.")
  end

  it "forces public" do
    expect(FactoryGirl.create(:reshare, public: false).public).to be true
  end

  describe "#root_diaspora_id" do
    let(:reshare) { create(:reshare, root: FactoryGirl.build(:status_message, author: bob.person, public: true)) }

    it "should return the root diaspora id" do
      expect(reshare.root_diaspora_id).to eq(bob.person.diaspora_handle)
    end

    it "should be nil if no root found" do
      reshare.root = nil
      expect(reshare.root_diaspora_id).to be_nil
    end
  end

  describe "#nsfw" do
    let(:sfw) { build(:status_message, author: alice.person, public: true) }
    let(:nsfw) { build(:status_message, author: alice.person, public: true, text: "This is #nsfw") }
    let(:sfw_reshare) { build(:reshare, root: sfw) }
    let(:nsfw_reshare) { build(:reshare, root: nsfw) }

    it "deletates #nsfw to the root post" do
      expect(sfw_reshare.nsfw).not_to be true
      expect(nsfw_reshare.nsfw).to be_truthy
    end
  end

  describe "#poll" do
    let(:root_post) { create(:status_message_with_poll, public: true) }
    let(:reshare) { create(:reshare, root: root_post) }

    it "contains root poll" do
      expect(reshare.poll).to eq root_post.poll
    end
  end

  describe "#absolute_root" do
    before do
      @status_message = FactoryGirl.build(:status_message, author: alice.person, public: true)
      reshare_1 = FactoryGirl.build(:reshare, root: @status_message)
      reshare_2 = FactoryGirl.build(:reshare, root: reshare_1)
      @reshare_3 = FactoryGirl.build(:reshare, root: reshare_2)

      status_message = FactoryGirl.create(:status_message, author: alice.person, public: true)
      reshare_1 = FactoryGirl.create(:reshare, root: status_message)
      @of_deleted = FactoryGirl.build(:reshare, root: reshare_1)
      status_message.destroy
      reshare_1.reload
    end

    it "resolves root posts to the top level" do
      expect(@reshare_3.absolute_root).to eq(@status_message)
    end

    it "can handle deleted reshares" do
      expect(@of_deleted.absolute_root).to be_nil
    end

    it "is used everywhere" do
      expect(@reshare_3.message).to eq @status_message.message
      expect(@of_deleted.message).to be_nil
      expect(@reshare_3.photos).to eq @status_message.photos
      expect(@of_deleted.photos).to be_empty
      expect(@reshare_3.o_embed_cache).to eq @status_message.o_embed_cache
      expect(@of_deleted.o_embed_cache).to be_nil
      expect(@reshare_3.open_graph_cache).to eq @status_message.open_graph_cache
      expect(@of_deleted.open_graph_cache).to be_nil
      expect(@reshare_3.mentioned_people).to eq @status_message.mentioned_people
      expect(@of_deleted.mentioned_people).to be_empty
      expect(@reshare_3.nsfw).to eq @status_message.nsfw
      expect(@of_deleted.nsfw).to be_nil
      expect(@reshare_3.address).to eq @status_message.location.try(:address)
      expect(@of_deleted.address).to be_nil
    end
  end

  describe "#post_location" do
    let(:status_message) { build(:status_message, text: "This is a status_message", author: bob.person, public: true) }
    let(:reshare) { create(:reshare, root: status_message) }

    context "with location" do
      let(:location) { build(:location) }

      it "should deliver address and coordinates" do
        status_message.location = location
        expect(reshare.post_location).to include(address: location.address, lat: location.lat, lng: location.lng)
      end
    end

    context "without location" do
      it "should deliver empty address and coordinates" do
        expect(reshare.post_location[:address]).to be_nil
        expect(reshare.post_location[:lat]).to be_nil
        expect(reshare.post_location[:lng]).to be_nil
      end
    end
  end
end
