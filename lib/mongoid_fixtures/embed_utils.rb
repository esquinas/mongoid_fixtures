# frozen_string_literal: true

module EmbedUtils
  def self.create_embedded_instance(clazz, hash, instance)
    embed = clazz.new

    unless hash.is_a? Hash
      raise("#{hash} was supposed to be a collection of #{embed}. \
        You have configured #{clazz} objects to be embedded instances of #{instance}. \
        Please store these objects within the #{instance} yml. Refer to the documentation for examples.")
    end

    hash.each do |key, value|
      embed.send("#{key}=", value)
    end
    embed.send("#{find_embed_parent_class(embed)}=", instance)
    embed
  end

  def self.find_embed_parent_class(embed)
    relations = embed.relations

    relations.each do |name, relation|
      return name if relation.is_a?(Mongoid::Association::Embedded::EmbeddedIn)
    end

    raise 'Unable to find parent class'
  end

  def self.insert_embedded_ids(instance)
    attributes = instance.attributes.reject { |key, _| key.to_s.eql?('_id') }

    attributes.each do |key, value|
      if attributes[key].is_a? Hash
        attributes[key]['_id'] = instance.send(key)._id unless instance.send(key)._id.nil?
      else
        attributes[key] = value
      end
    end
    attributes
  end
end
