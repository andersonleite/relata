require 'filtered_relation/dsl/conditions'
require 'filtered_relation/dsl/constraints'
require 'filtered_relation/dsl/querys/multiple'
require 'filtered_relation/dsl/querys/simple'
require 'filtered_relation/dsl/querys/fields'

# in case you did not require the entire filtered_relation plugin
module FilteredRelation
  module Dsl
  end
end

# defines helper methods to deal with custom relation
module FilteredRelation::Dsl::CustomRelation
  include Conditions
  include Constraints
  
  def using(record, field)    
    @record = record
    @current_field = field
    @start_field = field
    @select_fields = ["#{table_name}.*"]
    @groups = []
    if relates_to_many?
      self.extend MultipleQuery
      self.extend ModelFields      
    else
      self.extend SimpleQuery
    end
    
    self
  end

  private
  
  def relates_to_many?
    @record.reflect_on_association @current_field.to_sym
  end

end

# a relation search in a specific field
class FilteredRelation::Dsl::FieldSearch
  
  def initialize(rel, field)
    @rel = rel
    @field = field
  end

  def >=(value)
    @rel.where(@field).count.ge(value)
  end
  
  def like?(value)
    @rel.where(@field).like?(value)
  end
  
  def exists?
    @rel.where(@field).exists?
  end
  
  def between(first, second)
    @rel.where("#{@field} > ? and #{@field} < ?", first, second)
  end

end

# a builder ready to collect which field you want to search
class FilteredRelation::Dsl::MissedBuilder
  
  def initialize(rel)
    @rel = rel
  end
  
  def method_missing(field, *args)
    if args.size != 0
      raise "Unable to setup a parameter with args: #{field} and #{args}"
    end
    FilteredRelation::Dsl::FieldSearch.new(@rel, field)
  end
  
end

module FilteredRelation::Dsl::Relation

  # extended where clause that allows symbol and custom dsl lookup
  #
  # examples:
  # where(:body).like?("%guilherme%")
  # where { body.like?("%guilherme%")
  #
  # While the last will delegate to the MissedBuilder component
  # the symbol based query will delegate query builder to CustomRelation.
  def where(*args, &block)
    if args.size==0 && block
      FilteredRelation::Dsl::MissedBuilder.new(self).instance_eval(&block)
    elsif args.size==1 && args[0].is_a?(Symbol)
      relation = scoped
      relation.extend FilteredRelation::Dsl::CustomRelation
      relation.using(self, args[0])
    else
      super(*args, &block)
    end
  end
end

class ActiveRecord::Relation
  include FilteredRelation::Dsl::Relation
end
