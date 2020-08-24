require_relative '../lib/mongoid_fixtures/version'
require 'yaml'
require 'singleton'
require 'linguistics'
require 'active_support/inflector'
require 'monkey_patches/module'
require_relative 'mongoid_fixtures/embed_utils'

module MongoidFixtures

  class Loader
    include Singleton

    attr_accessor :fixtures, :path

    def initialize
      @fixtures = {}
    end

    def self.load
      if Dir.exist?("#{path}")
        load_fixtures Dir["#{path}/*.yml"]
      elsif Dir.exist?("../#{path}")
        load_fixtures Dir["../#{path}/*.yml"]
      else
        raise('Unable to find fixtures in either /test/fixtures or ../test/fixtures')
      end
    end

    def self.load_fixtures(fixture_names)
      fix = MongoidFixtures::Loader.instance
      fixture_names.each do |fixture|
        fix.fixtures[File.basename(fixture, '.*')] = YAML.load_file(fixture)
      end
      fix
    end

    def self.path=(var)
      Loader.instance.path = var
    end

    def self.path
      Loader.instance.path
    end
  end
  # :private

  Linguistics.use(:en)
  Loader.path = 'test/fixtures'
  Loader.load

  def self.load(clazz)
    fixture_instances = Loader.instance.fixtures[clazz.to_s.downcase.en.plural] # get class name
    instances = {}
    if fixture_instances.nil?
      raise "Could not find instances for #{clazz}"
    end
    fixture_instances.each do |key, fixture_instance|
      instance = clazz.new
      fields = fixture_instance.keys
      fields.each do |field|

        value = fixture_instance[field]
        field_label = field.to_s.capitalize
        field_clazz = Module.resolve_class_ignore_plurality(field_label)

        # If the current value is a symbol then it represents another fixture.
        # Find it and store its id
        if value.is_a?(Symbol) || value.nil?
          relations = instance.relations
          if relations.include? field
            # if relations[field].relation.eql? Mongoid::Relations::Referenced::In or relations[field].relation.eql? Mongoid::Relations::Referenced::One
            if relations[field].is_a?(Mongoid::Association::Referenced::BelongsTo) || \
               relations[field].is_a?(Mongoid::Association::Referenced::HasOne)
              instance.send("#{field}=", self.load(field_clazz)[value])
            else
              # instance[field] = self.load(field_clazz)[value].id # embedded fields?
              raise "#{instance} relationship not defined: #{relations[field]}"
            end
          else
            raise "Symbol (#{value.nil? ? value : 'nil'}) doesn't reference relationship"
          end

        elsif value.is_a? Array
          values = []
          value.each do |v|
            if field_clazz.nil?
              values << v
            else
              values << EmbedUtils.create_embedded_instance(field_clazz, v, instance)
            end
          end
          if instance[field].nil?
            instance[field] = []
          end
          instance[field].concat(values)
        elsif value.is_a? Hash
          # take hash convert it to object and serialize it
          instance[field] = EmbedUtils.create_embedded_instance(field_clazz, value, instance)
          # else just set the field
        else
          if include_setter?(instance, field)
            instance.send("#{field}=", value)
          else
            instance[field] = value
          end
        end
      end
      instances[key] = create_or_save_instance(instance) # store it based on its key name
    end
    instances
  end

  def self.include_setter?(instance, setter)
    instance.class.instance_methods.include? "#{setter}=".to_sym
  end

  def self.flatten_attributes(attributes)
    flattened_attributes = {}
    if attributes.is_a? String
      return attributes
    end
    if attributes.is_a? Mongoid::Document
      attributes.attributes.each do |name, attribute|
        unless name.eql? '_id'
          flattened_attributes["#{attributes.class.to_s.downcase}.#{name}"] = attribute
        end
      end
    else

      attributes.each do |key, values|
        if values.is_a? Hash
          values.each do |value, inner_value|
            flattened_attributes["#{key}.#{value}"] = inner_value
          end
        elsif values.is_a? Mongoid::Document
          values.attributes.each do |name, attribute|
            unless name.eql? '_id'
              flattened_attributes["#{values.class.to_s.downcase}.#{name}"] = values.send(name)
            end
          end
        elsif values.is_a? Array # Don't do anything
        else
          flattened_attributes[key] = values
        end
      end
    end
    flattened_attributes
  end

  :private

  def self.create_or_save_instance(instance)
    attributes = instance.attributes.select { |key, value| !key.to_s.eql?('_id') }
    flattened_attributes = flatten_attributes(attributes)
    if instance.class.where(flattened_attributes).exists?
      instance = instance.class.where(flattened_attributes).first
    else
      EmbedUtils.insert_embedded_ids(instance)
      instance.save! # auto serialize the document
    end
    instance
  end

  :private


end
