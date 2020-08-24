require_relative '../lib/mongoid_fixtures'
require 'mongoid'
require 'rspec'
require 'bcrypt'

Mongoid.load!(File.join(File.expand_path('../..', __FILE__), '/config.yml'), :development)

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

  alias_method(:longitude, :x)
  alias_method(:latitude, :y)
  alias_method(:altitude, :z)
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
      MongoidFixtures.load(State).should_not be_nil
    end
  end

  describe '.load(City)' do
    it 'loads City fixture data into the db and returns a hash of all cities and relations' do
      cities = MongoidFixtures.load(City)
      cities.should_not be_nil
      new_york_city = cities[:new_york_city]
      new_york_city.should_not be_nil
      new_york_city.state.should be_a State
      new_york_city.geo_uri_scheme.should be_a GeoUriScheme
      new_york_city.population.should be_a Population
      population = new_york_city.population
      population.total.should eq 9000000
      population.rank.should eq 1
      population.density.should eq '10,756.0/km2'
      population.msa.should eq  20092883
      population.csa.should eq  23632722
      population.source.should eq  'U.S. Census (2014)'

      new_york_city.people.should_not be_empty

      christopher_big_wallace = new_york_city.people[-1]
      christopher_big_wallace.first_name.should eq 'Christopher'
      christopher_big_wallace.middle_name.should eq 'George'
      christopher_big_wallace.paternal_surname.should eq 'Latore'
      christopher_big_wallace.maternal_surname.should eq 'Wallace'
      christopher_big_wallace.nick_names.should eq ['The Notorious B.I.G.', 'B.I.G.', 'Biggie Smalls', 'Big Poppa', 'Frank White', 'King of New York']
      christopher_big_wallace.born.should eq (Date.parse('Sun, 21 May 1972'))
      christopher_big_wallace.died.should eq (Date.parse('Sun, 09 Mar 1997'))
      christopher_big_wallace.description.should eq 'was an American rapper. Wallace is consistently ranked as one of the greatest rappers ever and one of the most influential rappers of all time.'

      terrytown = cities[:terrytown]
      terrytown.should_not be_nil
      terrytown.state.should be_a State
      terrytown.geo_uri_scheme.should be_a GeoUriScheme

    end
  end

  describe '.load(GeoURIScheme)' do
    it 'loads GeoURIScheme fixture data into the db and returns a hash of all GeoUriSchemes' do
      MongoidFixtures.load(GeoUriScheme).should_not be_nil
      terrytown = MongoidFixtures.load(GeoUriScheme)[:terrytown]
      terrytown._id.should_not be_nil

      terrytown.x.should eq(-90.029444)
      terrytown.y.should eq(29.902222)
      terrytown.z.should eq(3.9624)
    end
  end

  describe '.load(User)' do
    it 'loads attributes based on accessors and not fields' do
      user = MongoidFixtures.load(User)[:example_user]
      user.password.should_not eq('test_password')
    end
  end
end
