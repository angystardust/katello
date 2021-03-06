#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'katello_test_helper'

module Katello
describe Api::V1::SystemGroupErrataController do
  include AuthorizationHelperMethods
  include OrchestrationHelper
  include OrganizationHelperMethods
  include SystemHelperMethods

  let(:user_with_read_permissions) { user_with_permissions { |u| u.can(:read_systems, :system_groups, @group.id, @organization) } }
  let(:user_with_update_permissions) { user_with_permissions { |u| u.can(:update_systems, :system_groups, @group.id, @organization) } }
  let(:user_without_update_permissions) { user_without_permissions }

  let(:uuid) { '1234' }
  let(:errata) { %w[RHBA-2012:0001 RHSA-2012:0002] }

  describe "(katello)" do

  before(:each) do
    setup_controller_defaults_api

    disable_consumer_group_orchestration
    setup_system_creation
    System.any_instance.stub(:update_system_groups)

    @environment = create_environment(:name => "DEV", :label => "DEV", :prior => @organization.library, :organization => @organization)
    @system      = create_system(:name => "verbose", :environment => @environment, :cp_type => "system", :facts => { "Test1" => 1, "verbose_facts" => "Test facts" })

    @group = SystemGroup.new(:name => "test_group", :organization => @organization, :max_systems => 5)
    @group.save!
    @group.systems << @system
    SystemGroup.stubs(:find).returns(@group)
  end

  describe "viewing errata" do
    before (:each) do
      types = [Glue::Pulp::Errata::SECURITY, Glue::Pulp::Errata::ENHANCEMENT, Glue::Pulp::Errata::BUGZILLA]

      to_ret = []
      5.times { |num|
        errata           = OpenStruct.new
        errata.id        = "8a604f44-6877-4c81-b6f9-#{num}"
        errata.errata_id = "RHSA-2011-01-#{num}"
        errata.type      = types[rand(3)]
        errata.release   = "Red Hat Enterprise Linux 6.0"
        errata.applicable_consumers = []
        to_ret << errata
      }
      SystemGroup.any_instance.stubs(:errata).returns(to_ret)
    end

    let(:action) { :index }
    let(:req) { get :index, :organization_id => @organization.name, :system_group_id => @group.id }
    subject { req }
    let(:authorized_user) { user_with_update_permissions }
    let(:unauthorized_user) { user_without_update_permissions }

    it_should_behave_like "protected action"

    it "should retrieve errata from pulp" do
      subject
    end

    it "should be successful" do
      subject
      must_respond_with(:success)
    end

  end

  describe "install errata" do
    before do
      @group.stubs(:install_errata).returns(TaskStatus.new)
    end

    let(:action) { :create }
    let(:req) { post :create, :organization_id => @organization.name, :system_group_id => @group.id, :errata_ids => errata }
    subject { req }
    let(:authorized_user) { user_with_update_permissions }
    let(:unauthorized_user) { user_without_update_permissions }

    it_should_behave_like "protected action"

    it "should call model to install errata" do
      @group.expects(:install_errata)
      subject
    end

    it "should be successful" do
      subject
      must_respond_with(:success)
    end

  end
  end
end
end
