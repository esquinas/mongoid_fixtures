# frozen_string_literal: true

require_relative '../lib/mongoid_fixtures'
require 'mongoid'
require 'rspec'
require 'bcrypt'

Mongoid.load!(File.join(File.expand_path('..', __dir__), '/config.yml'), :development)

class GeopoliticalDivision
  include Mongoid::Document
  field :name, type: String
  field :time_zone, type: String
  field :demonym, type: String
  field :settled, type: Integer
  field :consolidated, type: Integer
  field :custom_attributes, type: Array
  belongs_to :geo_uri_scheme
  embeds_one :population
  embeds_many :people
end

class Population
  include Mongoid::Document

  field :total, type: Integer
  field :rank, type: Integer
  field :density, type: String
  field :msa, type: Integer
  field :csa, type: Integer
  field :source, type: String
  embedded_in :geopolitical_division
end

class City < GeopoliticalDivision
  include Mongoid::Document
  belongs_to :state
end

class State < GeopoliticalDivision
  include Mongoid::Document

  field :motto, type: String
  field :admission_to_union, type: String

  has_many :cities
end

class GeoUriScheme
  include Mongoid::Document

  field :x, type: Float
  field :y, type: Float
  field :z, type: Float

  has_many :geopolitical_divisions

  alias longitude x
  alias latitude y
  alias altitude z
end

class Person
  include Mongoid::Document

  embedded_in :geopolitical_division

  field :first_name, type: String
  field :paternal_surname, type: String
  field :born, type: Date
  field :description, type: String
  field :middle_name, type: String
  field :suffix, type: String
  field :died, type: Date
  field :maternal_surname, type: String
  field :nick_names, type: Array
end

class User
  include Mongoid::Document
  include BCrypt
  field :user_name, type: String
  field :password, type: String

  def password=(password)
    self[:password] = Password.create(password)
  end
end

describe MongoidFixtures do
  describe '.load' do
    it 'loads fixtures into the db and returns a hash of the fixtures' do
      expect(MongoidFixtures.load(State)).to_not be_nil
    end
  end

  describe '.load(City)' do
    it 'loads City fixture data into the db and returns a hash of all cities and relations' do
      cities = MongoidFixtures.load(City)
      expect(cities).to_not be_nil
      new_york_city = cities[:new_york_city]
      expect(new_york_city).not_to be_nil
      expect(new_york_city.state).to be_a State
      expect(new_york_city.geo_uri_scheme).to be_a GeoUriScheme
      expect(new_york_city.population).to be_a Population
      population = new_york_city.population
      expect(population.total).to eq(9_000_000)
      expect(population.rank).to eq(1)
      expect(population.density).to eq('10,756.0/km2')
      expect(population.msa).to eq(20_092_883)
      expect(population.csa).to eq(23_632_722)
      expect(population.source).to eq('U.S. Census (2014)')

      expect(new_york_city.people).to_not be_empty

      christopher_big_wallace = new_york_city.people[-1]
      expect(christopher_big_wallace.first_name).to eq('Christopher')
      expect(christopher_big_wallace.middle_name).to eq('George')
      expect(christopher_big_wallace.paternal_surname).to eq('Latore')
      expect(christopher_big_wallace.maternal_surname).to eq('Wallace')
      expect(christopher_big_wallace.nick_names).to eq(['The Notorious B.I.G.', 'B.I.G.', 'Biggie Smalls', 'Big Poppa', 'Frank White', 'King of New York'])
      expect(christopher_big_wallace.born).to eq(Date.parse('Sun, 21 May 1972'))
      expect(christopher_big_wallace.died).to eq(Date.parse('Sun, 09 Mar 1997'))
      expect(christopher_big_wallace.description).to eq(<<~END_DESC.chomp)
        was an American rapper. Wallace is consistently ranked as one of the greatest rappers ever and one of the most influential rappers of all time.
      END_DESC

      terrytown = cities[:terrytown]
      expect(terrytown).to_not be_nil
      expect(terrytown.state).to be_a State
      expect(terrytown.geo_uri_scheme).to be_a GeoUriScheme
    end
  end

  describe '.load(GeoURIScheme)' do
    it 'loads GeoURIScheme fixture data into the db and returns a hash of all GeoUriSchemes' do
      expect(MongoidFixtures.load(GeoUriScheme)).to_not be_nil
      terrytown = MongoidFixtures.load(GeoUriScheme)[:terrytown]
      expect(terrytown._id).to_not be_nil

      expect(terrytown.x).to eq(-90.029444)
      expect(terrytown.y).to eq(29.902222)
      expect(terrytown.z).to eq(3.9624)
    end
  end

  describe '.load(User)' do
    it 'loads attributes based on accessors and not fields' do
      user = MongoidFixtures.load(User)[:example_user]
      expect(user.password).to_not eq('test_password')
    end
  end
end
