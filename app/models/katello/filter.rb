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

module Katello
class Filter < Katello::Model
  self.include_root_in_json = false

  belongs_to :content_view_definition,
             :class_name => "Katello::ContentViewDefinitionBase",
             :inverse_of => :filters
  has_many :rules, :class_name => "Katello::FilterRule", :dependent => :destroy

  # rubocop:disable HasAndBelongsToMany
  # TODO: change these into has_many :through associations
  has_and_belongs_to_many :repositories, :uniq => true, :class_name => "Katello::Repository", :join_table => :katello_filters_repositories
  has_and_belongs_to_many :products, :uniq => true, :class_name => "Katello::Product", :join_table => :katello_filters_products

  validate :validate_content_definition
  validate :validate_products_and_repos
  validates :name, :presence => true, :allow_blank => false,
                   :uniqueness => {:scope => :content_view_definition_id}
  validates_with Validators::KatelloNameFormatValidator, :attributes => :name

  def self.applicable(repo)
    query = %{katello_filters.id in (select filter_id from  katello_filters_repositories where repository_id = #{repo.id})
              OR katello_filters.id in (select filter_id from  katello_filters_products where product_id = #{repo.product_id}) }
    where(query).select("DISTINCT katello_filters.id")
  end

  def as_json(options = {})
    super(options).update("content_view_definition_label" => content_view_definition.label,
                          "organization" => content_view_definition.organization.label,
                          "products" =>  products.collect(&:name),
                          "repos" => repositories.collect(&:name),
                          "rules" => rules)
  end

  def validate_content_definition
    if self.content_view_definition.composite?
      errors.add(:base, _("cannot contain filters if composite definition"))
    end
  end

  def validate_filter_products_and_repos(errors, cvd)
    prod_diff = self.products - cvd.resulting_products
    repo_diff = self.repositories - cvd.repos
    unless prod_diff.empty?
      errors.add(:base, _("cannot contain filters whose products do not belong to this content view definition"))
    end
    unless repo_diff.empty?
      errors.add(:base, _("cannot contain filters whose repositories do not belong to this content view definition"))
    end
  end

  def clone_for_archive
    filter = Filter.new(:name => self.name)
    filter.content_view_definition_id = nil
    filter.products = self.products
    filter.repositories = self.repositories
    if Rails.version >= "3.1"
      filter.rules = self.rules.map(&:dup)
    else
      filter.rules = self.rules.map(&:clone)
    end

    filter
  end

  def resulting_products
    (self.products + self.repositories.collect{|r| r.product}).uniq
  end

  def repos(env)
    repos = self.products.map { |prod| prod.repos(env) }.flatten.reject(&:puppet?)
    repos + repositories
  end

  def puppet_repository
    repositories.puppet_type.first
  end

  def puppet_repository_id
    puppet_repository.try(:id)
  end

  protected

  def validate_products_and_repos
    validate_filter_products_and_repos(self.errors, self.content_view_definition)
  end

end
end
