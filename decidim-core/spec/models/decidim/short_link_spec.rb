# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe ShortLink do
    subject { short_link }

    let(:short_link) do
      create(
        :short_link,
        target: target,
        mounted_engine_name: engine_name,
        route_name: route_name,
        params: params
      )
    end
    let(:target) { create(:dummy_resource) }
    let(:engine_name) { "decidim_participatory_process_dummy" }
    let(:route_name) { "dummy_resource" }
    let(:params) { {} }

    describe ".to" do
      subject { described_class.to(target, engine_name, route_name: route_name, params: params) }

      it "creates a unique short link within the target organization" do
        expect(subject).to be_a(described_class)
        expect(subject.organization).to be(target.organization)
        expect(subject.target).to be(target)
        expect(subject.mounted_engine_name).to eq(engine_name)
        expect(subject.route_name).to eq(route_name)
        expect(subject.params).to eq(params)
      end

      context "with link existing for the same parameters" do
        let(:params) { { foo: "bar" } }

        # Make sure the link exists
        before { short_link }

        it "returns the existing link" do
          expect(subject).to eq(short_link)
        end
      end
    end

    describe ".unique_identifier_within" do
      subject { described_class.unique_identifier_within(organization) }

      let(:organization) { create(:organization) }

      it "returns a 10 character long alphanumeric string" do
        expect(subject).to match(/[a-zA-Z0-9]{10}/)
      end

      context "when the first two identifiers are taken" do
        let(:taken_identifier_1) { "abcDEF1234" }
        let(:taken_identifier_2) { "GHIjkl5678" }
        let!(:existing_link_1) { create(:short_link, target: organization, identifier: taken_identifier_1) }
        let!(:existing_link_2) { create(:short_link, target: organization, identifier: taken_identifier_2) }

        it "generates an available identifier" do
          expect(SecureRandom).to receive(:alphanumeric).with(10).once.ordered.and_return(taken_identifier_1)
          expect(SecureRandom).to receive(:alphanumeric).with(10).once.ordered.and_return(taken_identifier_2)
          expect(SecureRandom).to receive(:alphanumeric).with(10).once.ordered.and_call_original

          expect(subject).to match(/[a-zA-Z0-9]{10}/)
          expect(subject).not_to eq(taken_identifier_1)
          expect(subject).not_to eq(taken_identifier_2)
        end

        context "and the link is created for another organization" do
          subject { described_class.unique_identifier_within(another_organization) }

          let(:another_organization) { create(:organization) }

          it "returns the identifier already in use in the other organization" do
            expect(SecureRandom).to receive(:alphanumeric).with(10).once.and_return(taken_identifier_1)

            expect(subject).to eq(taken_identifier_1)
          end
        end
      end
    end

    describe "#route_name" do
      it "returns the defined route name" do
        expect(subject.route_name).to eq(route_name)
      end

      context "when the route name is not defined" do
        let(:route_name) { nil }

        it "returns the root route name" do
          expect(subject.route_name).to eq("root")
        end
      end
    end

    describe "#short_url" do
      it "returns the short URL" do
        expect(subject.short_url).to eq("http://#{target.organization.host}/s/#{subject.identifier}")
      end
    end

    describe "#target_url" do
      let(:resource_url) do
        Decidim::ResourceLocatorPresenter.new(target).url
      end

      it "returns the target URL" do
        expect(subject.target_url).to eq(resource_url)
      end

      context "with extra parameters" do
        let(:params) { { foo: "bar", baz: "biz" } }

        it "returns the target URL with the parameters" do
          expect(subject.target_url).to eq("#{resource_url}?baz=biz&foo=bar")
        end
      end

      context "when the target is a participatory space" do
        let(:target) { create(:participatory_process) }
        let(:engine_name) { "decidim_participatory_processes" }
        let(:route_name) { "participatory_process" }

        it "returns the target URL" do
          expect(subject.target_url).to eq("http://#{target.organization.host}/processes/#{target.slug}")
        end
      end

      context "when the target is an organization" do
        let(:target) { create(:organization) }
        let(:engine_name) { "decidim" }
        let(:route_name) { "pages" }

        it "returns the target URL" do
          expect(subject.target_url).to eq("http://#{target.host}/pages")
        end
      end

      context "when the target is a static page" do
        let(:target) { create(:static_page) }
        let(:engine_name) { "decidim" }
        let(:route_name) { "page" }

        it "returns the target URL" do
          expect(subject.target_url).to eq("http://#{target.organization.host}/pages/#{target.slug}")
        end
      end
    end
  end
end
