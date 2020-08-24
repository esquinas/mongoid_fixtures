# frozen_string_literal: true

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
      if Dir.exist?(path.to_s)
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

  Linguistics.use(:en)
  Loader.path = 'test/fixtures'
  Loader.load

  def self.load(clazz)
    fixture_instances = Loader.instance.fixtures[clazz.to_s.downcase.en.plural] # get class name
    instances = {}
    raise "Could not find instances for #{clazz}" if fixture_instances.nil?

    fixture_instances.each do |key, fixture_instance|
      instance = clazz.new
      fields = fixture_instance.keys
      fields.each do |field|
        value = fixture_instance[field]
        field_label = field.to_s.capitalize
        field_clazz = Module.resolve_class_ignore_plurality(field_label)

        # If the current value is a symbol then it represents another fixture.
        # Find it and store its id
        case value
        when Symbol, NilClass
          relations = instance.relations
          raise "Symbol (#{value.nil? ? value : 'nil'}) doesn't reference relationship" unless relations.include?(field)

          unless relations[field].is_a?(Mongoid::Association::Referenced::BelongsTo) || \
                 relations[field].is_a?(Mongoid::Association::Referenced::HasOne)
            # instance[field] = self.load(field_clazz)[value].id # embedded fields?
            raise "#{instance} relationship not defined: #{relations[field]}"
          end

          instance.send("#{field}=", self.load(field_clazz)[value])

        when Array
          values = []
          value.each do |v|
            values << if field_clazz.nil?
                        v
                      else
                        EmbedUtils.create_embedded_instance(field_clazz, v, instance)
                      end
          end
          instance[field] = [] if instance[field].nil?
          instance[field].concat(values)

        when Hash
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
    return attributes if attributes.is_a? String

    if attributes.is_a? Mongoid::Document
      attributes.attributes.each do |name, attribute|
        flattened_attributes["#{attributes.class.to_s.downcase}.#{name}"] = attribute unless name.eql? '_id'
      end
    else

      attributes.each do |key, values|
        case values
        when Hash
          values.each do |value, inner_value|
            flattened_attributes["#{key}.#{value}"] = inner_value
          end
        when Mongoid::Document
          values.attributes.each do |name, _attribute|
            flattened_attributes["#{values.class.to_s.downcase}.#{name}"] = values.send(name) unless name.eql? '_id'
          end
        when Array
          # Don't do anything
        else
          flattened_attributes[key] = values
        end
      end
    end
    flattened_attributes
  end

  def self.create_or_save_instance(instance)
    attributes = instance.attributes.reject { |key, _value| key.to_s.eql?('_id') }
    flattened_attributes = flatten_attributes(attributes)
    if instance.class.where(flattened_attributes).exists?
      instance = instance.class.where(flattened_attributes).first
    else
      EmbedUtils.insert_embedded_ids(instance)
      instance.save! # auto serialize the document
    end
    instance
  end
end
